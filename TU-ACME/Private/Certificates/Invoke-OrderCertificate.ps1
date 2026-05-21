function Invoke-OrderCertificate {
    Invoke-ConsoleClear
    Write-Host '  === Order new certificate ===' -ForegroundColor Cyan
    Write-Host ''

    # UC-2.1: Domain validation. Accepts bare hostnames (e.g. "myserver"
    # for internal ACME CAs), FQDNs ("example.com", "sub.example.com"),
    # and wildcards ("*.example.com"). Rejects all-numeric labels via
    # the alphanumeric-first rule, leading/trailing hyphens, empty
    # labels, and stray dots.
    $domainRegex = '^(?:\*\.)?[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$'
    $mainDomain  = ''

    while ($mainDomain -eq '') {
        $domainInput = Read-Host '  Primary domain (e.g. example.com, *.example.com, or internal hostname)'
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

    $allDomains  = @($mainDomain) + $sans
    $hasWildcard = ($allDomains | Where-Object { $_ -match '^\*\.' }).Count -gt 0

    # Challenge type selection. HTTP-01 is offered in two flavours:
    #   - Self-hosted: Posh-ACME starts a temporary HTTP listener via
    #                 Windows http.sys. http.sys multiplexes by URL
    #                 prefix, so /.well-known/acme-challenge/ is routed
    #                 to our listener while IIS continues to serve
    #                 everything else on port 80 — no IIS restart, no
    #                 vdir, no rewrite. Same trick win-acme uses.
    #                 Listed first because it requires no web-server
    #                 configuration on the host.
    #   - WebRoot:    Posh-ACME writes the challenge file to a folder
    #                 served by your existing web server.
    $selfHostDisabled = $hasWildcard -or (-not $script:OnWindows)

    $labelSelfHost = if ($hasWildcard) {
        '1. HTTP-01 Self-hosted  (not available - wildcards require DNS-01)'
    } elseif (-not $script:OnWindows) {
        '1. HTTP-01 Self-hosted  (Windows only - uses http.sys to coexist with IIS)'
    } else {
        '1. HTTP-01 Self-hosted  (Posh-ACME starts an HTTP listener; coexists with IIS)'
    }
    $labelWebRoot = if ($hasWildcard) {
        '2. HTTP-01 WebRoot      (not available - wildcards require DNS-01)'
    } else {
        '2. HTTP-01 WebRoot      (web server serves the challenge file from a folder)'
    }
    $challengeOptions = @(
        $labelSelfHost,
        $labelWebRoot,
        '3. DNS-01               (DNS TXT record, required for wildcards)'
    )
    $disabled = @()
    if ($selfHostDisabled) { $disabled += 0 }
    if ($hasWildcard)      { $disabled += 1 }

    $challengeSel = Show-Menu -Title 'Select challenge type' `
        -Options $challengeOptions -DisabledIndices $disabled
    if ($challengeSel -lt 0) { return }

    $challengeType = switch ($challengeSel) {
        0 { 'HTTP-01-SelfHost' }
        1 { 'HTTP-01' }
        2 { 'DNS-01' }
    }

    if ($challengeType -eq 'HTTP-01') {
        $plugin     = 'WebRoot'
        $pluginArgs = _Collect-HTTP01Args
        if ($pluginArgs -eq $null) { return }
        $dnsConfig = $null
    } elseif ($challengeType -eq 'HTTP-01-SelfHost') {
        $plugin     = 'WebSelfHost'
        $pluginArgs = _Collect-HTTP01SelfHostArgs
        if ($pluginArgs -eq $null) { return }
        $dnsConfig = $null
    } else {
        $plugin = _Select-DNSPlugin
        if ($plugin -eq $null) { return }

        if ($plugin -eq 'AcmeDns') {
            $pluginArgs = _Collect-AcmeDnsArgs -Domains $allDomains
        } else {
            $pluginArgs = _Collect-PluginArgs -Plugin $plugin
        }
        if ($pluginArgs -eq $null) { return }

        $dnsConfig = _Configure-DNS01Challenge -Plugin $plugin
        if ($dnsConfig -eq $null) { return }
    }

    # Summary view
    Invoke-ConsoleClear
    Write-Host '  === Summary ===' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "  Domain:          $mainDomain" -ForegroundColor White
    if ($sans.Count -gt 0) {
        Write-Host "  SAN:             $($sans -join ', ')" -ForegroundColor White
    }
    $challengeTxt = switch ($challengeType) {
        'HTTP-01'          { 'HTTP-01 (WebRoot)' }
        'HTTP-01-SelfHost' { 'HTTP-01 (Self-hosted)' }
        'DNS-01'           { 'DNS-01' }
    }
    Write-Host "  Challenge:       $challengeTxt" -ForegroundColor White
    Write-Host "  Plugin:          $plugin" -ForegroundColor White
    if ($challengeType -eq 'HTTP-01') {
        Write-Host "  WebRoot:         $($pluginArgs.WRPath)" -ForegroundColor White
    } elseif ($challengeType -eq 'HTTP-01-SelfHost') {
        $portTxt = if ($pluginArgs.WSHPort) { $pluginArgs.WSHPort } else { '80 (default)' }
        Write-Host "  Listener port:   $portTxt" -ForegroundColor White
        Write-Host "  Listener timeout: $($pluginArgs.WSHTimeout) sec" -ForegroundColor White
    } else {
        Write-Host "  DNS sleep:       $($dnsConfig.DnsSleep) sec" -ForegroundColor White
        Write-Host "  Timeout:         $($dnsConfig.ValidationTimeout) sec" -ForegroundColor White
        $persistTxt = if ($dnsConfig.PersistentRecords) { 'Yes (records will not be deleted)' } else { 'No' }
        Write-Host "  Persistent DNS:  $persistTxt" -ForegroundColor $(if ($dnsConfig.PersistentRecords) { 'Yellow' } else { 'White' })
    }
    Write-Host ''

    if (-not (Confirm-YesNo '  Confirm order? (y/N)' -Default $false)) { return }

    # UC-2.2: Order certificate
    $result = $null

    Write-Host ''
    switch ($challengeType) {
        'HTTP-01'          { Write-Host '  [ > ] Writing challenge file and requesting validation...' -ForegroundColor Cyan }
        'HTTP-01-SelfHost' { Write-Host '  [ > ] Starting HTTP listener and requesting validation...' -ForegroundColor Cyan }
        'DNS-01'           { Write-Host '  [ > ] Creating DNS TXT record...' -ForegroundColor Cyan }
    }

    try {
        $certParams = @{
            Domain     = $allDomains
            Plugin     = $plugin
            PluginArgs = $pluginArgs
            AcceptTOS  = $true
        }
        if ($challengeType -eq 'DNS-01') {
            $certParams['DnsSleep']          = $dnsConfig.DnsSleep
            $certParams['ValidationTimeout'] = $dnsConfig.ValidationTimeout
        }

        $spinnerMsg = switch ($challengeType) {
            'HTTP-01'          { 'Waiting for HTTP-01 validation...' }
            'HTTP-01-SelfHost' { 'Listener running; waiting for ACME server to fetch the token...' }
            'DNS-01'           { "Waiting for DNS propagation ($($dnsConfig.DnsSleep) sec)..." }
        }

        $result = Show-Spinner -Message $spinnerMsg -ScriptBlock {
            New-PACertificate @certParams
        }
    } catch {
        $errMsg = "$_"
        Write-Host ''
        Write-Host '  [ERROR] Certificate order failed:' -ForegroundColor Red
        Write-Host "  $errMsg" -ForegroundColor Red

        if ($_.Exception.InnerException) {
            Write-Host "  Inner: $($_.Exception.InnerException.Message)" -ForegroundColor DarkYellow
        }
        if ($_.ScriptStackTrace) {
            Write-Host ''
            Write-Host '  Script stack (top 5 frames):' -ForegroundColor DarkGray
            $_.ScriptStackTrace -split "`r?`n" | Select-Object -First 5 | ForEach-Object {
                Write-Host "    $_" -ForegroundColor DarkGray
            }
        }

        if ($errMsg -match 'rateLimited|too many') {
            Write-Host ''
            Write-Host '  Tip: You have hit the rate limit. Switch to Staging with [F3].' -ForegroundColor Yellow
        }
        if ($errMsg -match "property 'expires' cannot be found|Exception setting `"expires`"") {
            Write-Host ''
            Write-Host '  Compatibility tip: Posh-ACME on PowerShell 7 may reject an ACME order' -ForegroundColor Yellow
            Write-Host '                     response that omits the optional "expires" field' -ForegroundColor Yellow
            Write-Host '                     (RFC 8555 §7.1.3). Common with internal ACME CAs.' -ForegroundColor Yellow
            Write-Host '                     Options to try:' -ForegroundColor Yellow
            Write-Host '                       1. Run the same order from Windows PowerShell 5.1' -ForegroundColor Yellow
            Write-Host '                          (powershell.exe) - less strict about missing fields' -ForegroundColor Yellow
            Write-Host '                       2. Check your CA returns "expires" in /newOrder responses' -ForegroundColor Yellow
            Write-Host '                       3. Open an issue at https://github.com/rmbolger/Posh-ACME' -ForegroundColor Yellow
        }
        if ($challengeType -eq 'HTTP-01' -and $errMsg -match 'unauthorized|connection|fetching|404|403') {
            Write-Host ''
            Write-Host '  HTTP-01 tip: Verify that http://<domain>/.well-known/acme-challenge/ is reachable.' -ForegroundColor Yellow
            Write-Host '               Confirm the WebRoot path is correct and the web server serves static files there.' -ForegroundColor Yellow
        }
        if ($challengeType -eq 'HTTP-01-SelfHost' -and $errMsg -match 'AccessDenied|HttpListenerException|access is denied') {
            Write-Host ''
            Write-Host '  Self-host tip: HTTP listener could not bind. Run TU-ACME as Administrator.' -ForegroundColor Yellow
            Write-Host '                 If a non-Microsoft web server (nginx/Apache) holds port 80,' -ForegroundColor Yellow
            Write-Host '                 stop it first - http.sys cannot share with non-MS listeners.' -ForegroundColor Yellow
        }
        if ($challengeType -eq 'HTTP-01-SelfHost' -and $errMsg -match 'unauthorized|connection|fetching|timeout') {
            Write-Host ''
            Write-Host '  Self-host tip: ACME server could not reach the listener. Check that the' -ForegroundColor Yellow
            Write-Host '                 port is open in the firewall and reachable from the internet.' -ForegroundColor Yellow
        }
        if ($challengeType -eq 'DNS-01' -and $errMsg -match 'DNS|TXT|propagat|timeout') {
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

    if ($challengeType -eq 'DNS-01' -and $dnsConfig.PersistentRecords) {
        Write-Host ''
        Write-Host '  Note: DNS TXT records have not been deleted (persistent mode).' -ForegroundColor Yellow
        Write-Host '        Remove them manually at your DNS provider when they are no longer needed.' -ForegroundColor Yellow
    }

    Write-Host ''
    Wait-AnyKey
}

function _Collect-HTTP01Args {
    Invoke-ConsoleClear
    Write-Host '  === HTTP-01 Challenge (WebRoot) ===' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  The ACME server requests a file at:' -ForegroundColor Gray
    Write-Host '    http://<your-domain>/.well-known/acme-challenge/<token>' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Posh-ACME writes the challenge file under:' -ForegroundColor Gray
    Write-Host '    <WebRoot>/.well-known/acme-challenge/' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Common WebRoot paths:' -ForegroundColor DarkGray
    Write-Host '    IIS default site:  C:\inetpub\wwwroot' -ForegroundColor DarkGray
    Write-Host '    nginx default:     /var/www/html' -ForegroundColor DarkGray
    Write-Host '    Apache default:    /var/www/html' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Requirements:' -ForegroundColor Gray
    Write-Host '   - The web server must serve files from this directory' -ForegroundColor DarkGray
    Write-Host '   - Port 80 must be reachable from the ACME server' -ForegroundColor DarkGray
    Write-Host '   - The directory (and .well-known/acme-challenge) must be writable' -ForegroundColor DarkGray
    Write-Host ''

    $path = Read-Host '  WebRoot path (blank = cancel)'
    if ($path -eq '') { return $null }

    return @{ WRPath = $path.Trim() }
}

function _Collect-HTTP01SelfHostArgs {
    Invoke-ConsoleClear
    Write-Host '  === HTTP-01 Challenge (Self-hosted) ===' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  Posh-ACME starts a temporary HTTP listener that responds to' -ForegroundColor Gray
    Write-Host '  the ACME validation request itself. Uses Windows http.sys to' -ForegroundColor Gray
    Write-Host '  multiplex by URL prefix: /.well-known/acme-challenge/ goes to' -ForegroundColor Gray
    Write-Host '  our listener, everything else stays with IIS - no restart,' -ForegroundColor Gray
    Write-Host '  no vdir, no rewrite. Same trick win-acme uses.' -ForegroundColor Gray
    Write-Host ''
    Write-Host '  Requirements:' -ForegroundColor Gray
    Write-Host '   - Run TU-ACME as Administrator (http.sys binding needs elevation)' -ForegroundColor DarkGray
    Write-Host '   - Chosen port must be reachable from the ACME server (firewall)' -ForegroundColor DarkGray
    Write-Host '   - Non-Microsoft servers (nginx/Apache on Windows) do NOT share' -ForegroundColor DarkGray
    Write-Host '     http.sys; stop them first if they hold the port' -ForegroundColor DarkGray
    Write-Host ''

    $portInput = Read-Host '  Listener port (blank = 80)'
    $port = $portInput.Trim()
    if ($port -ne '') {
        $parsed = 0
        if (-not ([int]::TryParse($port, [ref] $parsed)) -or $parsed -lt 1 -or $parsed -gt 65535) {
            Write-Host "  Invalid port - falling back to 80." -ForegroundColor Yellow
            $port = ''
        }
    }

    $timeoutInput = Read-Host '  Listener timeout in seconds (blank = 120)'
    $timeout = 120
    if ($timeoutInput -ne '') {
        $parsed = 0
        if ([int]::TryParse($timeoutInput, [ref] $parsed) -and $parsed -gt 0) {
            $timeout = $parsed
        } else {
            Write-Host "  Invalid number - using default (120 sec)." -ForegroundColor Yellow
        }
    }

    return @{
        WSHPort    = $port
        WSHTimeout = $timeout
    }
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
    } catch {
        Write-Host "  Warning: Could not enumerate DNS plugins: $_" -ForegroundColor Yellow
        Write-EventLogEntry -EventId 2001 -EntryType Warning `
            -Message "TU-ACME: Get-PAPlugin failed: $_"
    }

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
        } catch {
            Write-Host "  Warning: Could not parse $existingPath - $_" -ForegroundColor Yellow
            Write-EventLogEntry -EventId 2002 -EntryType Warning `
                -Message "TU-ACME: ACME-DNS account JSON unreadable at $existingPath - $_"
        }
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
