function Invoke-OrderCertificate {
    Invoke-ConsoleClear
    Write-Host '  === Order new certificate ===' -ForegroundColor Cyan
    Write-Host ''

    # UC-2.1: Domain validation
    $domainRegex = '^(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
    $mainDomain  = ''

    while ($mainDomain -eq '') {
        $domainInput = Read-Host '  Primary domain (e.g. example.com)'
        if ($domainInput -match $domainRegex) {
            $mainDomain = $domainInput.Trim().ToLower()
        } else {
            Write-Host '  Invalid domain name. Please try again.' -ForegroundColor Red
        }
    }

    # SAN domains (optional)
    $sans = @()
    Write-Host '  Additional domains/SAN (comma-separated, blank = none):' -ForegroundColor Gray
    $sanInput = Read-Host '  SAN'
    if ($sanInput -ne '') {
        foreach ($s in ($sanInput -split ',')) {
            $s = $s.Trim().ToLower()
            if ($s -match $domainRegex) {
                $sans += $s
            } else {
                Write-Host "  '$s' is not a valid domain name and will be skipped." -ForegroundColor Yellow
            }
        }
    }

    # UC-3.1: Select DNS plugin
    $plugin = _Select-DNSPlugin
    if ($plugin -eq $null) { return }

    # UC-3.2 + 3.3 / UC-3.5: Collect plugin parameters
    $allDomains = @($mainDomain) + $sans
    if ($plugin -eq 'AcmeDns') {
        $pluginArgs = _Collect-AcmeDnsArgs -Domains $allDomains
    } else {
        $pluginArgs = _Collect-PluginArgs -Plugin $plugin
    }
    if ($pluginArgs -eq $null) { return }

    # UC-3.4: DNS-01 challenge configuration
    $dnsConfig = _Configure-DNS01Challenge -Plugin $plugin
    if ($dnsConfig -eq $null) { return }

    # Summary view
    Invoke-ConsoleClear
    Write-Host '  === Summary ===' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "  Domain:          $mainDomain" -ForegroundColor White
    if ($sans.Count -gt 0) {
        Write-Host "  SAN:             $($sans -join ', ')" -ForegroundColor White
    }
    Write-Host "  Plugin:          $plugin" -ForegroundColor White
    Write-Host "  Challenge:       DNS-01" -ForegroundColor White
    Write-Host "  DNS sleep:       $($dnsConfig.DnsSleep) sec" -ForegroundColor White
    Write-Host "  Timeout:         $($dnsConfig.ValidationTimeout) sec" -ForegroundColor White
    $persistTxt = if ($dnsConfig.PersistentRecords) { 'Yes (records will not be deleted)' } else { 'No' }
    Write-Host "  Persistent DNS:  $persistTxt" -ForegroundColor $(if ($dnsConfig.PersistentRecords) { 'Yellow' } else { 'White' })
    Write-Host ''

    if (-not (Confirm-YesNo '  Confirm order? (Y/N)')) { return }

    # UC-2.2: Order certificate with DNS-01 step
    $result = $null

    Write-Host ''
    Write-Host '  [ > ] Creating DNS TXT record...' -ForegroundColor Cyan

    try {
        $result = Show-Spinner -Message "Waiting for DNS propagation ($($dnsConfig.DnsSleep) sec)..." -ScriptBlock {
            $certParams = @{
                Domain            = $allDomains
                Plugin            = $plugin
                PluginArgs        = $pluginArgs
                DnsSleep          = $dnsConfig.DnsSleep
                ValidationTimeout = $dnsConfig.ValidationTimeout
                AcceptTOS         = $true
            }
            New-PACertificate @certParams
        }
    } catch {
        $errMsg = "$_"
        Write-Host ''
        Write-Host '  [ERROR] Certificate order failed:' -ForegroundColor Red
        Write-Host "  $errMsg" -ForegroundColor Red

        if ($errMsg -match 'rateLimited|too many') {
            Write-Host ''
            Write-Host '  Tip: You have hit the rate limit. Switch to Staging with [F3].' -ForegroundColor Yellow
        }
        if ($errMsg -match 'DNS|TXT|propagat|timeout') {
            Write-Host ''
            Write-Host '  DNS tip: Increase DnsSleep to 300+ seconds and try again.' -ForegroundColor Yellow
            Write-Host '           Verify that the TXT record has been created at your DNS provider.' -ForegroundColor Yellow
        }
        Write-Host ''
        Wait-AnyKey
        return
    }

    # Success
    Write-Host ''
    Write-Host '  Certificate ordered!' -ForegroundColor Green
    if ($result) {
        Write-Host "  Domain:     $($result.MainDomain)" -ForegroundColor White
        Write-Host "  Expires:    $($result.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor White
        Write-Host "  Thumbprint: $($result.Thumbprint)" -ForegroundColor White
    }

    if ($dnsConfig.PersistentRecords) {
        Write-Host ''
        Write-Host '  Note: DNS TXT records have not been deleted (persistent mode).' -ForegroundColor Yellow
        Write-Host '        Remove them manually at your DNS provider when they are no longer needed.' -ForegroundColor Yellow
    }

    Write-Host ''
    Wait-AnyKey
}

function _Configure-DNS01Challenge {
    param([string] $Plugin)

    $config     = Get-TUACMEConfig
    $dnsDefaults = $config.DNS

    $defaultSleep   = if ($dnsDefaults -and $dnsDefaults.DefaultDnsSleep)          { $dnsDefaults.DefaultDnsSleep }          else { 120 }
    $defaultTimeout = if ($dnsDefaults -and $dnsDefaults.DefaultValidationTimeout) { $dnsDefaults.DefaultValidationTimeout } else { 60 }
    $defaultPersist = if ($dnsDefaults -and $dnsDefaults.PersistentRecords)         { $dnsDefaults.PersistentRecords }         else { $false }

    Invoke-ConsoleClear
    Write-Host '  === DNS-01 Challenge Settings ===' -ForegroundColor Cyan
    Write-Host ''

    if ($Plugin -eq 'Manual') {
        Write-Host '  Plugin: Manual — DNS TXT records are created and deleted manually.' -ForegroundColor Yellow
        Write-Host '  Records are not removed automatically after validation.' -ForegroundColor DarkGray
        Write-Host ''
    }

    # DnsSleep
    Write-Host "  DNS propagation wait time (DnsSleep):" -ForegroundColor Gray
    Write-Host "  Default: $defaultSleep seconds" -ForegroundColor DarkGray
    $sleepInput = Read-Host "  Enter seconds (blank = $defaultSleep)"
    $dnsSleep   = $defaultSleep
    if ($sleepInput -ne '') {
        $parsed = 0
        if ([int]::TryParse($sleepInput, [ref] $parsed) -and $parsed -ge 0) {
            $dnsSleep = $parsed
        } else {
            Write-Host "  Invalid number — using default ($defaultSleep sec)." -ForegroundColor Yellow
        }
    }

    Write-Host ''

    # ValidationTimeout
    Write-Host "  Validation timeout:" -ForegroundColor Gray
    Write-Host "  Default: $defaultTimeout seconds" -ForegroundColor DarkGray
    $timeoutInput      = Read-Host "  Enter seconds (blank = $defaultTimeout)"
    $validationTimeout = $defaultTimeout
    if ($timeoutInput -ne '') {
        $parsed = 0
        if ([int]::TryParse($timeoutInput, [ref] $parsed) -and $parsed -ge 0) {
            $validationTimeout = $parsed
        } else {
            Write-Host "  Invalid number — using default ($defaultTimeout sec)." -ForegroundColor Yellow
        }
    }

    Write-Host ''

    # Persistent mode (only relevant for non-Manual plugins)
    $persistentRecords = $defaultPersist
    if ($Plugin -ne 'Manual') {
        $persistInput = Read-Host "  Keep DNS TXT records after validation? (Y/N, default: $(if ($defaultPersist) { 'Y' } else { 'N' }))"
        if ($persistInput -match '^[Yy]') {
            $persistentRecords = $true
            Write-Host ''
            Write-Host '  Warning: TXT records will remain visible in DNS after validation.' -ForegroundColor Yellow
            Write-Host '            Remove them manually at your DNS provider when they are no longer in use.' -ForegroundColor Yellow
        } elseif ($persistInput -match '^[Nn]') {
            $persistentRecords = $false
        }
    }

    # Save as new defaults
    Write-Host ''
    if (Confirm-YesNo '  Save as default settings? (Y/N)') {
        $config.DNS = [PSCustomObject]@{
            DefaultDnsSleep          = $dnsSleep
            DefaultValidationTimeout = $validationTimeout
            PersistentRecords        = $persistentRecords
        }
        Set-TUACMEConfig -Config $config
        Write-Host '  DNS settings saved.' -ForegroundColor Green
    }

    return [PSCustomObject]@{
        DnsSleep          = $dnsSleep
        ValidationTimeout = $validationTimeout
        PersistentRecords = $persistentRecords
    }
}

function _Select-DNSPlugin {
    $plugins = @()
    try {
        $plugins = @(Get-PAPlugin 2>$null | Select-Object -ExpandProperty Plugin)
    } catch {}

    if ($plugins.Count -eq 0) {
        Write-Host '  No DNS plugins found. Using Manual validation.' -ForegroundColor Yellow
        return 'Manual'
    }

    $sel = Show-Menu -Title 'Select DNS plugin (DNS-01 challenge)' -Options $plugins -AllowSearch
    if ($sel -lt 0) { return $null }
    return $plugins[$sel]
}

function _Collect-PluginArgs {
    param([string] $Plugin)

    $pArgs = @{}

    if ($Plugin -eq 'Manual') { return $pArgs }

    try {
        $guide = Get-PAPluginArgs -Plugin $Plugin 2>$null
    } catch {
        return $pArgs
    }

    if (-not $guide) { return $pArgs }

    Write-Host ''
    Write-Host "  Enter parameters for plugin: $Plugin" -ForegroundColor Cyan

    foreach ($param in $guide.PSObject.Properties) {
        $name     = $param.Name
        $isSecret = $name -match 'Key|Token|Secret|Password|Pass|Credential'

        if ($isSecret) {
            $val = ConvertTo-MaskedInput -Prompt "  $name" -AsSecureString
            if ($val -eq $null) { return $null }
        } else {
            $val = Read-Host "  $name"
        }
        $pArgs[$name] = $val
    }

    return $pArgs
}

function _Collect-AcmeDnsArgs {
    param([string[]] $Domains)

    $primaryDomain = $Domains[0] -replace '^\*\.', ''
    $existingPath  = Get-AcmeDnsAccountPath -Domain $primaryDomain
    $config        = Get-TUACMEConfig

    if ($existingPath) {
        Invoke-ConsoleClear
        Write-Host '  === ACME-DNS ===' -ForegroundColor Cyan
        Write-Host ''
        Write-Host "  Saved account found: $existingPath" -ForegroundColor Green
        try {
            $data = Get-Content -Path $existingPath -Raw | ConvertFrom-Json
            Write-Host "  FullDomain: $($data.fulldomain)" -ForegroundColor White
        } catch {}
        Write-Host ''

        if (Confirm-YesNo '  Reuse existing account? (Y/N)') {
            $server = if ($config.DNS -and $config.DNS.AcmeDnsServer) {
                $config.DNS.AcmeDnsServer
            } else {
                Read-Host '  ACME-DNS server URL'
            }
            return @{
                ACMEDnsServer      = $server
                ACMEDnsAccountJson = $existingPath
            }
        }
    }

    $result = Invoke-AcmeDnsSetup -Domains $Domains
    if ($result -eq $null) { return $null }

    if (-not $config.DNS) {
        $config.DNS = [PSCustomObject]@{
            DefaultDnsSleep          = 120
            DefaultValidationTimeout = 60
            PersistentRecords        = $false
            AcmeDnsServer            = $result.ACMEDnsServer
        }
    } else {
        $config.DNS | Add-Member -NotePropertyName 'AcmeDnsServer' -NotePropertyValue $result.ACMEDnsServer -Force
    }
    Set-TUACMEConfig -Config $config

    return $result
}
