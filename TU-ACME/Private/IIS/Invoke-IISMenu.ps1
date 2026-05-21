function Invoke-IISMenu {
    if (-not $script:OnWindows) {
        Write-Host ''
        Write-Host '  IIS Integration is only available on Windows.' -ForegroundColor Yellow
        Write-Host ''
        Wait-AnyKey
        return
    }

    if (-not $script:TUACMEIsAdmin) {
        Show-StatusBar -AdminWarning 'IIS Integration requires administrator privileges'
        Start-Sleep -Seconds 2
        return
    }

    # Check that WebAdministration is available
    try {
        Import-Module WebAdministration -ErrorAction Stop
    } catch {
        Write-Host ''
        Write-Host '  [ERROR] The WebAdministration module is not available.' -ForegroundColor Red
        Write-Host '  IIS may not be installed on this system.' -ForegroundColor Yellow
        Write-Host ''
        Wait-AnyKey
        return
    }

    while ($true) {
        $options = @(
            '1. Show HTTPS bindings',
            '2. Bind certificate to IIS binding',
            'B. Back'
        )
        $sel = Show-Menu -Title 'IIS Integration' -Options $options

        switch ($sel) {
            -1 { return }
            0  { _Show-IISBindings }
            1  { _Bind-CertToIIS }
            2  { return }
        }
    }
}

function _Show-IISBindings {
    Invoke-ConsoleClear
    Write-Host '  === HTTPS Bindings ===' -ForegroundColor Cyan
    Write-Host ''

    $bindings = @(Get-WebBinding -Protocol 'https' -ErrorAction SilentlyContinue)

    if ($bindings.Count -eq 0) {
        Write-Host '  No HTTPS bindings found.' -ForegroundColor Yellow
        Write-Host ''
        Wait-AnyKey
        return
    }

    # Fetch Posh-ACME certificate thumbprints for comparison
    $paCerts = @{}
    try {
        Get-PACertificate -List 2>$null | ForEach-Object {
            if ($_.Thumbprint) { $paCerts[$_.Thumbprint.ToUpper()] = $_.MainDomain }
        }
    } catch {
        Write-Host "  Warning: Could not enumerate Posh-ACME certificates: $_" -ForegroundColor Yellow
        Write-EventLogEntry -EventId 2003 -EntryType Warning `
            -Message "TU-ACME: Get-PACertificate failed in IIS binding view: $_"
    }

    $rows = $bindings | ForEach-Object {
        $tp     = if ($_.certificateHash) { $_.certificateHash.ToUpper() } else { '' }
        $match  = if ($paCerts.ContainsKey($tp)) { $paCerts[$tp] } else { '-' }
        [PSCustomObject]@{
            Site       = $_.ItemXPath -replace ".*\[@name='(.+?)'\].*", '$1'
            Binding    = $_.bindingInformation
            Thumbprint = if ($tp.Length -gt 16) { $tp.Substring(0, 16) + '...' } else { $tp }
            PoshACME   = $match
        }
    }

    $colorRule = {
        param($row)
        if ($row.PoshACME -ne '-') { 'Green' } else { 'White' }
    }

    Show-Table -Data $rows `
        -Columns @('Site', 'Binding', 'Thumbprint', 'PoshACME') `
        -Headers @('Site', 'Binding', 'Thumbprint', 'Posh-ACME match') `
        -Widths  @(20, 25, 20, 20) `
        -ColorRule $colorRule

    Write-Host ''
    Wait-AnyKey
}

function _Bind-CertToIIS {
    # Select certificate from Posh-ACME
    $certs = @(Get-PACertificate -List 2>$null)
    if ($certs.Count -eq 0) {
        Write-Host '  No Posh-ACME certificates found.' -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        return
    }

    $certOptions = $certs | ForEach-Object { $_.MainDomain }
    $certSel     = Show-Menu -Title 'Select certificate' -Options $certOptions
    if ($certSel -lt 0) { return }
    $cert = $certs[$certSel]

    # Select bindings (multi-select with spacebar)
    $bindings = @(Get-WebBinding -Protocol 'https' -ErrorAction SilentlyContinue)
    if ($bindings.Count -eq 0) {
        Write-Host '  No HTTPS bindings found.' -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        return
    }

    Invoke-ConsoleClear
    Write-Host '  === Select bindings (Spacebar = toggle, Enter = confirm) ===' -ForegroundColor Cyan
    Write-Host ''

    $selected = @($false) * $bindings.Count
    $index    = 0

    function Render-BindingList {
        Set-ConsoleCursorPos -X 0 -Y 2
        for ($i = 0; $i -lt $bindings.Count; $i++) {
            $check  = if ($selected[$i]) { '[X]' } else { '[ ]' }
            $site   = $bindings[$i].ItemXPath -replace ".*\[@name='(.+?)'\].*", '$1'
            $bind   = $bindings[$i].bindingInformation
            $line   = "  $check  $site  $bind"
            if ($i -eq $index) {
                Write-Host $line.PadRight(79) -ForegroundColor Black -BackgroundColor Cyan
            } else {
                Write-Host $line.PadRight(79) -ForegroundColor White
            }
        }
    }

    Render-BindingList
    Set-ConsoleCursorVisible -Visible $false

    while ($true) {
        $key = Invoke-ConsoleReadKey
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow)   { if ($index -gt 0) { $index-- }; Render-BindingList }
            ([ConsoleKey]::DownArrow) { if ($index -lt $bindings.Count - 1) { $index++ }; Render-BindingList }
            ([ConsoleKey]::Spacebar)  { $selected[$index] = -not $selected[$index]; Render-BindingList }
            ([ConsoleKey]::Escape)    { Set-ConsoleCursorVisible -Visible $true; return }
            ([ConsoleKey]::Enter)     { break }
        }
        if ($key.Key -eq [ConsoleKey]::Enter) { break }
    }

    Set-ConsoleCursorVisible -Visible $true

    $toUpdate = 0..($bindings.Count - 1) | Where-Object { $selected[$_] }
    if ($toUpdate.Count -eq 0) {
        Write-Host '  No bindings selected. Aborting.' -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        return
    }

    # Import certificate to Windows Store
    try {
        Import-PfxCertificate -FilePath $cert.PfxFile `
            -CertStoreLocation 'Cert:\LocalMachine\My' -Exportable | Out-Null
    } catch {
        Write-Host "  Warning: Could not import to certificate store: $_" -ForegroundColor Yellow
    }

    # Update bindings
    foreach ($i in $toUpdate) {
        $b    = $bindings[$i]
        $site = $b.ItemXPath -replace ".*\[@name='(.+?)'\].*", '$1'
        try {
            $b.certificateHash = $cert.Thumbprint
            $b | Set-WebBinding
            Write-Host "  Updated: $site $($b.bindingInformation)" -ForegroundColor Green
            Write-EventLogEntry -EventId 1002 -Message "IIS binding updated: $site - new thumbprint: $($cert.Thumbprint)"
        } catch {
            Write-Host "  Error updating $site : $_" -ForegroundColor Red
            Write-EventLogEntry -EventId 3002 -Message "IIS binding error: $site - $_" -EntryType Error
        }
    }

    Write-Host ''
    Wait-AnyKey
}

# Post-renewal IIS rebind is now handled automatically by
# Invoke-RenewalBackground.ps1 (Posh-ACME v4 has no native -PostScript
# hook, so the rebind runs from TU-ACME's own renewal wrapper instead).
# No menu item needed.
