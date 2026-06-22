<#
    Wizard.ps1 - Invoke-NewCertificate (the N menu, 6 steps) and the three
    WACS-style pickers (sites, host headers, common name).
#>

function Select-IISSitesUI {
    $selectedSites = $null
    while ($true) {
        Clear-Host
        Write-Step 'Step 1: Select IIS Sites'
        Write-Host '   * = Selected'
        Write-Host ''

        $currentSites = @()
        try {
            $mgr    = Get-IISServerManagerSafe
            $selIds = if ($selectedSites) { $selectedSites.Id } else { @() }
            foreach ($site in $mgr.Sites) {
                $marker = if ($site.Id -in $selIds) { '*' } else { ' ' }
                $currentSites += [pscustomobject]@{
                    Selected = $marker
                    Id       = $site.Id
                    Name     = $site.Name
                    State    = [string]$site.State
                }
            }
        } catch {
            Write-Err "Error accessing IIS: $_"
        }

        if ($currentSites) {
            Write-Host (($currentSites | Sort-Object Id |
                Select-Object Selected, Id, Name, State | Format-Table -AutoSize | Out-String))
        } else {
            Write-Warn 'No IIS Sites found on this server.'
        }

        Write-Host 'Options:' -ForegroundColor Cyan
        Write-Host "  s <filter>   Filter by site IDs (e.g. 's 1,3') or 's s' for all sites"
        Write-Host '  c            Confirm selection & continue to bindings'
        Write-Host '  x            Cancel'

        $line = Read-Host 'Command'
        if (-not $line) { continue }
        $parts = $line.Trim() -split '\s+', 2
        $cmd   = $parts[0].ToLower()
        $arg   = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }

        switch ($cmd) {
            's' {
                if (-not $arg) { Write-Warn "Provide a filter (e.g. 's 1,3' or 's s')."; Wait-UI; continue }
                $temp = Get-IISFilteredSites $arg
                if (-not $temp) { Write-Warn 'No sites match that filter.'; Wait-UI; continue }
                $selectedSites = $temp
            }
            'c' {
                if (-not $selectedSites) {
                    Write-Warn 'No sites selected yet; defaulting to ALL sites.'
                    Start-Sleep -Seconds 1
                    $mgr = Get-IISServerManagerSafe
                    return @(foreach ($s in $mgr.Sites) {
                        [pscustomobject]@{ Id = $s.Id; Name = $s.Name; State = [string]$s.State }
                    })
                }
                return $selectedSites
            }
            'x' { throw 'Cancelled by user.' }
            default { Write-Warn 'Unknown command. Use s/c/x.'; Wait-UI }
        }
    }
}

function Select-IISBindingsUI {
    param([Parameter(ValueFromPipeline = $true)][object[]]$Sites)
    begin { $collected = @() }
    process { if ($null -ne $_) { $collected += $_ } }
    end {
        if (-not $collected) {
            $mgr = Get-IISServerManagerSafe
            $collected = @(foreach ($s in $mgr.Sites) {
                [pscustomobject]@{ Id = $s.Id; Name = $s.Name; State = [string]$s.State }
            })
        }

        $hostPatterns = @()
        $hostRegex    = $null
        $manual       = $null

        while ($true) {
            Clear-Host
            Write-Step 'Step 2: Filter Host Headers'
            Write-Host "Sites Included: $($collected.Name -join ', ')"
            Write-Host ''

            $raw = Get-IISBindingsRaw | Where-Object {
                $_.SiteName -in $collected.Name -and
                ($_.Protocol -ieq 'http' -or $_.Protocol -ieq 'https') -and
                $_.HostHeader -ne '' -and $_.HostHeader -ne '*'
            }

            $filtered = $raw
            if ($hostPatterns) { $filtered = $filtered | Where-Object { Test-WacsHostPattern $_.HostHeader $hostPatterns } }
            if ($hostRegex)    { $filtered = $filtered | Where-Object { $_.HostHeader -match $hostRegex } }

            $display = @()
            $i = 0
            foreach ($b in $filtered) {
                $i++
                $mark = if ($null -eq $manual -or $b.HostHeader -in $manual) { '*' } else { ' ' }
                $display += [pscustomobject]@{
                    Idx        = $i
                    Selected   = $mark
                    SiteName   = $b.SiteName
                    Protocol   = $b.Protocol
                    IPAddress  = $b.IPAddress
                    Port       = $b.Port
                    HostHeader = $b.HostHeader
                }
            }

            if ($display) {
                Write-Host (($display | Select-Object Idx, Selected, SiteName, Protocol, IPAddress, Port, HostHeader |
                    Format-Table -AutoSize | Out-String))
            } else {
                Write-Warn 'No matching bindings.'
            }

            Write-Host 'Active Filters:' -ForegroundColor Yellow
            if ($hostPatterns) { Write-Host "  Pattern: $($hostPatterns -join ',')" }
            if ($hostRegex)    { Write-Host "  Regex  : $hostRegex" }
            if (-not $hostPatterns -and -not $hostRegex) { Write-Host '  None (showing all)' }
            if ($null -ne $manual) { Write-Host "  Manual Selection: Enabled ($($manual.Count) selected)" -ForegroundColor Cyan }

            Write-Host ''
            Write-Host 'Options:' -ForegroundColor Cyan
            Write-Host "  p <pattern>   Filter by host pattern (e.g. 'p example.*')"
            Write-Host "  r <regex>     Filter by host regex (e.g. 'r ^.*\.contoso\.com$')"
            Write-Host "  s <number>    Toggle specific binding (e.g. 's 2')"
            Write-Host '  clear         Reset all filters and selections'
            Write-Host '  c             Confirm selection & continue to CN selection'
            Write-Host '  x             Cancel'

            $line = Read-Host 'Command'
            if (-not $line) { continue }
            $parts = $line.Trim() -split '\s+', 2
            $cmd   = $parts[0].ToLower()
            $arg   = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }

            switch ($cmd) {
                'p' {
                    if (-not $arg) { Write-Warn 'Provide a pattern.'; Wait-UI; continue }
                    $hostPatterns = ConvertTo-WacsFilter $arg
                    $hostRegex = $null; $manual = $null
                }
                'r' {
                    if (-not $arg) { Write-Warn 'Provide a regex.'; Wait-UI; continue }
                    try { $null = [regex]::new($arg); $hostRegex = $arg }
                    catch { Write-Warn 'Invalid regex.'; Wait-UI; continue }
                    $hostPatterns = @(); $manual = $null
                }
                's' {
                    if (-not $arg -or $arg -notmatch '^\d+$') { Write-Warn "Provide a number (e.g. 's 2')."; Wait-UI; continue }
                    $idx    = [int]$arg
                    $target = $display | Where-Object { $_.Idx -eq $idx }
                    if (-not $target) { Write-Warn 'Number out of range.'; Wait-UI; continue }
                    if ($null -eq $manual) { $manual = @($display | Select-Object -ExpandProperty HostHeader) }
                    if ($target.HostHeader -in $manual) {
                        $manual = @($manual | Where-Object { $_ -ne $target.HostHeader })
                        Write-Host "Deselected: $($target.HostHeader)"
                    } else {
                        $manual += $target.HostHeader
                        Write-Host "Selected: $($target.HostHeader)"
                    }
                    Wait-UI
                }
                'clear' {
                    $hostPatterns = @(); $hostRegex = $null; $manual = $null
                    Write-Host 'Filters and selections reset.'
                    Wait-UI
                }
                'c' {
                    $final = if ($null -eq $manual) {
                        @($filtered | Select-Object -ExpandProperty HostHeader -Unique)
                    } else { @($manual) }
                    if (-not $final) {
                        Write-Warn "No bindings selected. Press 'c' again to continue empty or 'clear' to reset."
                        Wait-UI
                    } else {
                        return $final
                    }
                }
                'x' { throw 'Cancelled by user.' }
                default { Write-Warn 'Unknown command. Use p/r/s/clear/c/x.'; Wait-UI }
            }
        }
    }
}

function Select-IISCommonNameUI {
    param([Parameter(ValueFromPipeline = $true)][string[]]$Hosts)
    begin { $collected = @() }
    process { if ($null -ne $_) { $collected += $_ } }
    end {
        $unique = @($collected | Select-Object -Unique)
        if (-not $unique) { throw 'No host headers selected.' }

        $selectedCN = $null
        while ($true) {
            Clear-Host
            Write-Step 'Step 3: Choose Common Name (CN)'
            Write-Host ''
            if (-not $selectedCN) {
                for ($i = 0; $i -lt $unique.Count; $i++) {
                    $mark = if ($i -eq 0) { '*' } else { ' ' }
                    Write-Host ("$mark  {0,2}: {1}" -f ($i + 1), $unique[$i])
                }
                Write-Host ''
                Write-Host 'Options:' -ForegroundColor Cyan
                Write-Host '  Press Enter     -> Use the default (*) = first host'
                Write-Host '  Type a number   -> Choose from the list above'
                Write-Host '  c <host>        -> Use any hostname as CN'
                Write-Host '  x               -> Cancel'
                $choice = Read-Host 'CN choice'
                $trimmed = $choice.Trim()
                if ($trimmed -ieq 'x') { throw 'Cancelled by user.' }
                elseif ($trimmed -eq '') { $selectedCN = $unique[0] }
                elseif ($trimmed -match '^\d+$') {
                    $idx = [int]$trimmed - 1
                    if ($idx -ge 0 -and $idx -lt $unique.Count) { $selectedCN = $unique[$idx] }
                    else { Write-Warn 'Number out of range.'; Wait-UI }
                }
                elseif ($trimmed -match '^c\s+(.+)$') { $selectedCN = $matches[1].Trim() }
                else { $selectedCN = $trimmed }
            } else {
                Write-Host 'You selected the following Common Name (CN):' -ForegroundColor Cyan
                Write-Host "  $selectedCN" -ForegroundColor Yellow
                Write-Host ''
                Write-Host 'Final certificate identifier list (CN first, then sorted):' -ForegroundColor Cyan
                $final = Get-OrderedIdentifiers -CommonName $selectedCN -Hosts $unique
                Write-Host ($final -join ', ')
                Write-Host ''
                Write-Host 'Options:' -ForegroundColor Cyan
                Write-Host '  y -> Confirm and continue'
                Write-Host '  r -> Reselect CN'
                Write-Host '  x -> Cancel'
                $conf = (Read-Host 'Confirm? (y/r/x)').Trim().ToLower()
                switch ($conf) {
                    'y' { return [pscustomobject]@{ CN = $selectedCN; Identifiers = $final } }
                    'r' { $selectedCN = $null }
                    'x' { throw 'Cancelled by user.' }
                    default { Write-Warn 'Invalid choice.'; Wait-UI }
                }
            }
        }
    }
}

function Get-OrderedIdentifiers {
    <#
        .SYNOPSIS
            Returns identifiers with the CN first, then the remaining hosts sorted.
            Pure function (no host I/O) so it is unit-testable.
    #>
    param(
        [Parameter(Mandatory)][string]$CommonName,
        [Parameter(Mandatory)][string[]]$Hosts
    )
    $rest = $Hosts | Where-Object { $_ -ne $CommonName } | Sort-Object
    return @($CommonName) + @($rest)
}

function Invoke-NewCertificate {
    Show-Banner
    Write-Step 'Create certificate (full options)'

    try {
        $result = Select-IISSitesUI | Select-IISBindingsUI | Select-IISCommonNameUI
    } catch {
        Write-Warn $_.Exception.Message
        Wait-UI
        return
    }

    $cn          = $result.CN
    $identifiers = $result.Identifiers

    # ---- Step 4: ACME options (read-only context + validation plugin) ----
    while ($true) {
        Clear-Host
        Write-Step 'Step 4: ACME options'
        $ctx     = Get-CurrentPAContext
        $srvName = if ($ctx.Server) { $ctx.Server.Name } else { $script:Config.ACMEServer }
        $acctID  = if ($ctx.Account) { $ctx.Account.id } else { '(none)' }
        $acctKey = if ($ctx.Account) { "$($ctx.Account.alg)/$($ctx.Account.KeyLength)" } else { '-' }
        Write-Host "CN            : $cn"
        Write-Host "Identifiers   : $($identifiers -join ', ')"
        Write-Host ''
        Write-Host 'Active context (read-only):'
        Write-Host "  Server            : $srvName"
        Write-Host "  Account           : $acctID"
        Write-Host "  Account key       : $acctKey"
        Write-Host "  Validation Plugin : $($script:Config.ValidationPlugin)"
        Write-Host "  Cert Store        : $($script:Config.CertStore)"
        Write-Host ''
        Write-Host 'Options:' -ForegroundColor Cyan
        Write-Host '  v <plugin>   Validation plugin (WebSelfHost | <DNS plugin>)'
        Write-Host '  c            Confirm and request certificate'
        Write-Host '  x            Cancel'

        $line = Read-Host 'Command'
        if (-not $line) { continue }
        $parts = $line.Trim() -split '\s+', 2
        $cmd   = $parts[0].ToLower()
        $arg   = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }
        switch ($cmd) {
            'v' { if ($arg) { $script:Config.ValidationPlugin = $arg; Save-TUACMEConfig } }
            'c' { break }
            'x' { return }
            default { Write-Warn 'Unknown command.' }
        }
        if ($cmd -eq 'c') { break }
    }

    $plugin = $script:Config.ValidationPlugin
    $store  = $script:Config.CertStore
    $server = if ((Get-CurrentPAContext).Server) { (Get-CurrentPAContext).Server.Name } else { $script:Config.ACMEServer }

    # ---- Invalid-order cleanup ----
    if (-not $script:DryRun) {
        $invalid = Get-PAInvalidOrdersForIdentifiers -Identifiers $identifiers
        if ($invalid) {
            Write-Host ''
            Write-Warn 'The following INVALID orders overlap this request and will block re-issue:'
            $invalid | ForEach-Object { Write-Host "  - $($_.MainDomain)  [$($_.Identifiers)]" -ForegroundColor Yellow }
            if (Confirm-Prompt 'Remove these invalid orders now?') {
                foreach ($o in $invalid) {
                    Invoke-PAAction -Description "Remove invalid order $($o.MainDomain)" `
                        -DryRunCommand "Remove-PAOrder -Name '$($o.Name)' -Force" `
                        -Action { Remove-PAOrder -Name $o.Name -Force }
                }
            } else {
                Write-Warn 'Issuance may fail while invalid orders exist. Aborting.'
                Wait-UI
                return
            }
        }
    }

    # ---- Redirect landmine warning (WebSelfHost / HTTP-01 only) ----
    if ($plugin -ieq 'WebSelfHost') {
        $sitesWithHosts = Get-IISBindingsRaw |
            Where-Object { $_.HostHeader -in $identifiers } |
            Select-Object -ExpandProperty SiteName -Unique
        foreach ($s in @($sitesWithHosts)) {
            if (Test-IISSiteHasHttpsRedirect -SiteName $s) {
                Write-Warn "Site '$s' has an HTTP->HTTPS redirect; it will 301 the ACME HTTP-01 challenge."
                Write-Warn "Exclude /.well-known/acme-challenge/ from the redirect, or use a DNS plugin."
            }
        }
    }

    # ---- Step 5: Confirm & run ----
    $domains    = $identifiers -join ','
    $serverArg  = Resolve-PAServerArg $server
    $cmdLine    = "New-PACertificate -Domain '$domains' -Plugin $plugin; " +
                  "Get-PACertificate '$($identifiers[0])' | " +
                  "Install-PACertificate -StoreLocation LocalMachine -StoreName $store"

    Clear-Host
    Write-Step 'Step 5: Confirm & run'
    Write-Host 'About to request a certificate with the following parameters:' -ForegroundColor Cyan
    Write-Host "  Domains          : $domains"
    Write-Host "  CN               : $cn"
    Write-Host "  ACME Server      : $server  $(if ($serverArg -ne $server) { "($serverArg)" })"
    Write-Host "  Validation       : $plugin"
    Write-Host "  Cert Store       : $store"
    Write-Host ''
    Write-Host 'Equivalent PowerShell command:' -ForegroundColor DarkCyan
    Write-Host "  $cmdLine" -ForegroundColor Gray
    Write-Host ''
    if (-not (Confirm-Prompt 'Proceed?')) { Write-Warn 'Cancelled.'; Wait-UI; return }

    $newCert = Invoke-PAAction -Description 'Request certificate' `
        -DryRunCommand "New-PACertificate -Domain '$domains' -Plugin $plugin" `
        -Action { New-PACertificate -Domain $identifiers -Plugin $plugin }

    if ($script:DryRun) {
        Write-Host ''
        Write-Warn 'DRY-RUN: No certificate was generated. Review the command above.'
        Write-Host 'Bindings that would be re-pointed (one per identifier):' -ForegroundColor Cyan
        foreach ($h in $identifiers) {
            $matching = Get-IISSslBindings | Where-Object { $_.HostHeader -ieq $h }
            if ($matching) {
                $matching | ForEach-Object { Write-Host ("    -> {0} / {1}" -f $_.SiteName, $_.BindingInfo) -ForegroundColor Gray }
            } else {
                Write-Host "    (no HTTPS binding for $h)" -ForegroundColor DarkGray
            }
        }
        Wait-UI
        return
    }

    if (-not $newCert -or -not $newCert.Thumbprint) {
        Write-Warn 'Certificate object was not returned. Verify Posh-ACME output above.'
        Wait-UI
        return
    }

    # ---- Install into the configured store (NOT New-PACertificate -Install) ----
    Invoke-PAAction -Description "Install certificate into LocalMachine\$store" `
        -DryRunCommand "Get-PACertificate '$($identifiers[0])' | Install-PACertificate -StoreLocation LocalMachine -StoreName $store" `
        -Action { Install-TUACMECertificate -OrderName $identifiers[0] -StoreName $store }

    $newTP = $newCert.Thumbprint
    Write-Ok "Certificate issued. Thumbprint: $newTP"
    Write-TUACMELog -Message "Issued certificate $newTP for $domains (store=$store)"

    # ---- Step 6: Bind IIS ----
    Write-Step 'Step 6: Bind IIS HTTPS bindings to the new certificate'

    # (a) Re-point existing HTTPS bindings whose host header is in the identifier set.
    $existing = @()
    foreach ($h in $identifiers) {
        $existing += @(Get-IISSslBindings | Where-Object { $_.HostHeader -ieq $h })
    }
    $ok = 0; $fail = 0
    if ($existing) {
        Write-Host 'Existing HTTPS bindings to re-point:' -ForegroundColor Cyan
        $existing | ForEach-Object { Write-Host ("  {0} / {1}  (current thumb: {2})" -f $_.SiteName, $_.BindingInfo, $_.Thumbprint) }
        if (Confirm-Prompt "Rebind $($existing.Count) binding(s) to new cert?") {
            foreach ($b in $existing) {
                try {
                    Set-IISBindingCertificate -SiteName $b.SiteName -BindingInformation $b.BindingInformation `
                        -Thumbprint $newTP -StoreName $store
                    Write-Ok "$($b.SiteName) / $($b.BindingInformation)"
                    $ok++
                } catch {
                    Write-Err "Failed: $($b.SiteName) / $($b.BindingInformation): $_"
                    $fail++
                }
            }
        }
    } else {
        Write-Info 'No existing HTTPS bindings match the requested identifiers.'
    }

    # (b) Offer to create new HTTPS bindings for HTTP-only host headers.
    $boundHosts = @($existing | Select-Object -ExpandProperty HostHeader)
    foreach ($h in $identifiers) {
        if ($h -in $boundHosts) { continue }
        $httpBinding = Get-IISBindingsRaw | Where-Object { $_.Protocol -ieq 'http' -and $_.HostHeader -ieq $h } | Select-Object -First 1
        if (-not $httpBinding) { continue }
        if (Confirm-Prompt "Create a new HTTPS binding for '$h' on site '$($httpBinding.SiteName)'?") {
            try {
                New-IISHttpsBinding -SiteName $httpBinding.SiteName -HostHeader $h `
                    -Thumbprint $newTP -StoreName $store
                Write-Ok "Created HTTPS binding for $h on $($httpBinding.SiteName)"
                $ok++
            } catch {
                Write-Err "Failed to create binding for ${h}: $_"
                $fail++
            }
        }
    }

    Write-Host ''
    Write-Ok "Bind complete. Success: $ok  Failed: $fail"
    Write-TUACMELog -Message "Bind summary for $newTP : ok=$ok failed=$fail"

    # ---- Post-deploy hook (non-IIS targets) ----
    if ($script:Config.PostDeployHook) {
        [void](Invoke-TUACMEPostDeployHook -Certificate $newCert -StoreName $store)
    }

    Wait-UI
}
