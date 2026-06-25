<#
    Renewals.ps1 - Manage renewals (M menu) and Browse IIS bindings (B menu).
    R (single) and A (all) from the reference are folded into the M menu.
#>

function Invoke-ManageRenewals {
    Show-Banner
    Write-Step 'Manage renewals'

    $orders = Get-PAOrdersList
    if (-not $orders) {
        Write-Warn 'No Posh-ACME orders found on this server.'
        Wait-UI
        return
    }

    $i = 0
    foreach ($o in $orders) {
        $i++
        $exp   = Format-PADate $o.NotAfter
        $renew = if ((ConvertTo-DateTime $o.RenewAfter) -and (ConvertTo-DateTime $o.RenewAfter) -le (Get-Date)) { 'DUE' } else { 'not due' }
        Write-Host ("  {0,2}: {1,-40} expires: {2}  ({3})  [{4}]  SAN: {5}" -f `
            $i, $o.MainDomain, $exp, $renew, $o.Status, $o.Identifiers)
    }
    Write-Host ''
    Write-Host 'Options:' -ForegroundColor Cyan
    Write-Host '  v <n>   View details of order #n'
    Write-Host '  r <n>   Force-renew order #n'
    Write-Host '  a       Renew all due orders (batch)'
    Write-Host '  d <n>   Delete order #n (does NOT revoke cert)'
    Write-Host '  c       Cancel'
    Write-Host ''

    $line = Read-Host 'Command'
    if (-not $line) { return }
    $parts = $line.Trim() -split '\s+', 2
    $cmd   = $parts[0].ToLower()
    $arg   = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }

    if ($cmd -eq 'c') { return }
    if ($cmd -eq 'a') { Invoke-RenewAll -Orders $orders; return }

    if (-not $arg -or $arg -notmatch '^\d+$') { Write-Warn 'Provide a number.'; Wait-UI; return }
    $idx = [int]$arg - 1
    if ($idx -lt 0 -or $idx -ge $orders.Count) { Write-Warn 'Out of range.'; Wait-UI; return }
    $order = $orders[$idx]

    switch ($cmd) {
        'v' {
            Clear-Host
            Write-Step "Order detail: $($order.MainDomain)"
            Write-Host "Name        : $($order.Name)"
            Write-Host "MainDomain  : $($order.MainDomain)"
            Write-Host "Identifiers : $($order.Identifiers)"
            Write-Host "Status      : $($order.Status)"
            Write-Host "Thumbprint  : $($order.CertThumb)"
            Write-Host "NotAfter    : $(Format-PADate $order.NotAfter)"
            Write-Host "RenewAfter  : $(Format-PADate $order.RenewAfter)"
            Write-Host "Location    : $($order.Location)"
            Write-Host ''
            $bound = if ($order.CertThumb) { Get-IISBindingsByThumbprint -Thumbprint $order.CertThumb } else { @() }
            if ($bound) {
                Write-Host 'IIS bindings currently using this certificate:' -ForegroundColor Cyan
                $bound | ForEach-Object { Write-Host ("  {0} / {1}" -f $_.SiteName, $_.BindingInfo) }
            } else {
                Write-Host 'IIS bindings currently using this certificate: NONE' -ForegroundColor DarkGray
            }
            Wait-UI
        }
        'r' { Invoke-RenewSingle -Order $order; Wait-UI }
        'd' {
            if (-not (Confirm-Prompt "Delete order '$($order.MainDomain)'? (Certificate will NOT be revoked.)")) { return }
            Invoke-PAAction -Description "Delete order $($order.MainDomain)" `
                -DryRunCommand "Remove-PAOrder -Name '$($order.Name)' -Force" `
                -Action { Remove-PAOrder -Name $order.Name -Force -ErrorAction SilentlyContinue }
            Wait-UI
        }
        default { Write-Warn 'Unknown command.'; Wait-UI }
    }
}

function Invoke-RenewSingle {
    <#
        .SYNOPSIS
            Force-renews one order and re-points its IIS bindings. Refuses to renew
            an Invalid order (delete + re-issue path instead).
    #>
    param([Parameter(Mandatory)][object]$Order)

    if ($Order.Status -ieq 'invalid') {
        Write-Err "Order '$($Order.MainDomain)' is INVALID and cannot be renewed."
        Write-Warn 'Delete it (d) and re-issue with the N menu instead.'
        return
    }

    $oldTP = $Order.CertThumb
    if (-not (Confirm-Prompt "Force-renew '$($Order.MainDomain)'?")) { return }

    Invoke-PAAction -Description "Select order '$($Order.Name)' as current" `
        -DryRunCommand "Get-PAOrder -Name '$($Order.Name)' | Out-Null" `
        -Action { Get-PAOrder -Name $Order.Name | Out-Null }

    $renewedCert = Invoke-PAAction -Description "Submit renewal for $($Order.MainDomain)" `
        -DryRunCommand 'Submit-Renewal -Force' `
        -Action { Submit-Renewal -Force }

    if ($script:DryRun -or $script:WhatIf) {
        $label = if ($script:DryRun) { 'DRY-RUN' } else { 'WHAT-IF' }
        Write-Warn "${label}: after a real renewal, IIS bindings using the old thumbprint would be re-pointed."
        return
    }

    if (-not $renewedCert) {
        try { $renewedCert = Get-PAOrder -Name $Order.Name | Get-PACertificate -ErrorAction Stop } catch { }
    }
    if (-not $renewedCert -or -not $renewedCert.Thumbprint) {
        Write-Err 'Renewal completed but the new certificate could not be loaded. Manual re-bind required.'
        return
    }

    $newTP = $renewedCert.Thumbprint
    Write-Ok "New certificate thumbprint: $newTP"
    Write-TUACMELog -Message "Renewed $($Order.MainDomain): $oldTP -> $newTP"

    Install-TUACMECertificate -OrderName $Order.Name -StoreName $script:Config.CertStore

    $sans = @($renewedCert.AllSANs)
    if (-not $sans) { $sans = @($Order.Identifiers -split ',') }
    $res = Update-IISCertificateBinding -Thumbprint $newTP -HostHeaders $sans `
        -OldThumbprint $oldTP -StoreName $script:Config.CertStore
    Write-Ok "Rebind complete. Success: $($res.Rebound)  Failed: $($res.Failed)"

    if ($script:Config.PostDeployHook) {
        [void](Invoke-TUACMEPostDeployHook -Certificate $renewedCert -StoreName $script:Config.CertStore)
    }
}

function Invoke-RenewAll {
    <#
        .SYNOPSIS
            Batch-renews all due orders via Submit-Renewal -AllOrders, then
            re-points IIS bindings for each renewed cert.
    #>
    param([object[]]$Orders)

    if (-not $Orders) { $Orders = Get-PAOrdersList }
    Write-Host ''
    Write-Step 'Run all renewals (batch)'
    Write-Host 'Orders considered for renewal:' -ForegroundColor Cyan
    foreach ($o in $Orders) {
        $exp   = Format-PADate $o.NotAfter
        $renew = if ((ConvertTo-DateTime $o.RenewAfter) -and (ConvertTo-DateTime $o.RenewAfter) -le (Get-Date)) { 'DUE' } else { 'not due' }
        Write-Host ("  {0,-40} expires {1}  ({2})" -f $o.MainDomain, $exp, $renew)
    }
    Write-Host ''
    if (-not (Confirm-Prompt 'Submit renewal for all due orders?')) { return }

    # Snapshot old thumbprints so we can fall back to thumbprint-match rebind.
    $thumbBefore = @{}
    foreach ($o in $Orders) { if ($o.CertThumb) { $thumbBefore[$o.Name] = $o.CertThumb } }

    $renewed = Invoke-PAAction -Description 'Submit renewal for all due orders' `
        -DryRunCommand 'Submit-Renewal -AllOrders' `
        -Action { Submit-Renewal -AllOrders }

    if ($script:DryRun -or $script:WhatIf) {
        $label = if ($script:DryRun) { 'DRY-RUN' } else { 'WHAT-IF' }
        Write-Warn "${label}: each due order would be renewed and its IIS bindings re-pointed."
        Wait-UI
        return
    }

    $ok = 0; $fail = 0
    foreach ($cert in @($renewed)) {
        if (-not $cert -or -not $cert.Thumbprint) { continue }
        $newTP = $cert.Thumbprint
        $oldTP = ''
        $sans = @($cert.AllSANs)
        # Find old thumbprint via any order whose identifiers overlap the SANs.
        $match = $Orders | Where-Object { @($_.Identifiers -split ',' | Where-Object { $_ -in $sans }).Count -gt 0 } | Select-Object -First 1
        if ($match) { $oldTP = $thumbBefore[$match.Name] }

        try { Install-TUACMECertificate -OrderName ($cert.MainDomain) -StoreName $script:Config.CertStore } catch {
            Write-Info "Install step skipped/failed for $newTP : $_"
        }
        $res = Update-IISCertificateBinding -Thumbprint $newTP -HostHeaders $sans `
            -OldThumbprint $oldTP -StoreName $script:Config.CertStore
        $ok  += $res.Rebound
        $fail += $res.Failed
        Write-Ok "$($cert.Subject): rebound=$($res.Rebound) failed=$($res.Failed)"
        Write-TUACMELog -Message "Batch renewed $newTP : rebound=$($res.Rebound) failed=$($res.Failed)"

        if ($script:Config.PostDeployHook) {
            if (-not (Invoke-TUACMEPostDeployHook -Certificate $cert -StoreName $script:Config.CertStore)) { $fail++ }
        }
    }
    Write-Host ''
    Write-Ok "Batch rebind complete. Success: $ok  Failed: $fail"
    Wait-UI
}

function Invoke-BrowseIISBindings {
    Show-Banner
    Write-Step 'Browse IIS bindings'

    $bindings = Get-IISSslBindings
    if (-not $bindings) {
        Write-Warn 'No HTTPS bindings found in IIS.'
        Wait-UI
        return
    }

    Write-Host (($bindings | Select-Object `
        @{ N = 'Site';       E = { $_.SiteName } },
        @{ N = 'Host';       E = { $_.HostHeader } },
        @{ N = 'IP:Port';    E = { "$($_.IPAddress):$($_.Port)" } },
        @{ N = 'Thumbprint'; E = { $_.Thumbprint } },
        @{ N = 'Subject';    E = { $_.Subject } },
        @{ N = 'Expires';    E = { Format-PADate $_.NotAfter } } |
        Format-Table -AutoSize | Out-String))

    Write-Host 'Filters:' -ForegroundColor Cyan
    Write-Host '  t <thumbprint>   Show only bindings using this cert thumbprint'
    Write-Host '  s <site>         Show only bindings on this site'
    Write-Host '  e                Show only certificates expiring within 30 days'
    Write-Host '  c                Clear filter'
    Write-Host '  x                Back to main menu'

    while ($true) {
        $line = Read-Host 'Filter (or x)'
        if (-not $line) { continue }
        $parts = $line.Trim() -split '\s+', 2
        $cmd   = $parts[0].ToLower()
        $arg   = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }
        switch ($cmd) {
            'x' { return }
            'c' { return }
            't' {
                if (-not $arg) { Write-Warn 'Provide a thumbprint.'; continue }
                Clear-Host
                Write-Step "Bindings using thumbprint: $arg"
                $filtered = $bindings | Where-Object { $_.Thumbprint -ieq $arg }
                if (-not $filtered) { Write-Warn 'No matches.'; Wait-UI; return }
                Write-Host (($filtered | Format-Table -AutoSize | Out-String))
                Wait-UI
                return
            }
            's' {
                if (-not $arg) { Write-Warn 'Provide a site name.'; continue }
                Clear-Host
                Write-Step "Bindings on site: $arg"
                $filtered = $bindings | Where-Object { $_.SiteName -ieq $arg }
                if (-not $filtered) { Write-Warn 'No matches.'; Wait-UI; return }
                Write-Host (($filtered | Format-Table -AutoSize | Out-String))
                Wait-UI
                return
            }
            'e' {
                Clear-Host
                Write-Step 'Bindings using certificates expiring within 30 days'
                $cutoff   = (Get-Date).AddDays(30)
                $filtered = $bindings | Where-Object { $_.NotAfter -and $_.NotAfter -le $cutoff }
                if (-not $filtered) { Write-Ok 'No certificates expiring within 30 days.'; Wait-UI; return }
                Write-Host (($filtered | Format-Table -AutoSize | Out-String))
                Wait-UI
                return
            }
            default { Write-Warn 'Unknown command.' }
        }
    }
}
