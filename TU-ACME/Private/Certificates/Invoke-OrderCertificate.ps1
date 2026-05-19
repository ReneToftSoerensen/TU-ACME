function Invoke-OrderCertificate {
    [Console]::Clear()
    Write-Host '  === Bestil nyt certifikat ===' -ForegroundColor Cyan
    Write-Host ''

    # UC-2.1: Domænevalidering
    $domainRegex = '^(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
    $mainDomain  = ''

    while ($mainDomain -eq '') {
        $input = Read-Host '  Primært domæne (f.eks. eksempel.dk)'
        if ($input -match $domainRegex) {
            $mainDomain = $input.Trim().ToLower()
        } else {
            Write-Host '  Ugyldigt domænenavn. Prøv igen.' -ForegroundColor Red
        }
    }

    # SAN-domæner (valgfrit)
    $sans = @()
    Write-Host '  Ekstra domæner/SAN (kommasepareret, blank = ingen):' -ForegroundColor Gray
    $sanInput = Read-Host '  SAN'
    if ($sanInput -ne '') {
        foreach ($s in ($sanInput -split ',')) {
            $s = $s.Trim().ToLower()
            if ($s -match $domainRegex) {
                $sans += $s
            } else {
                Write-Host "  '$s' er ikke et gyldigt domænenavn og springes over." -ForegroundColor Yellow
            }
        }
    }

    # UC-3.1: Vælg DNS-plugin
    $plugin = _Select-DNSPlugin
    if ($plugin -eq $null) { return }

    # UC-3.2 + 3.3 / UC-3.5: Indsaml plugin-parametre
    $allDomains = @($mainDomain) + $sans
    if ($plugin -eq 'AcmeDns') {
        $pluginArgs = _Collect-AcmeDnsArgs -Domains $allDomains
    } else {
        $pluginArgs = _Collect-PluginArgs -Plugin $plugin
    }
    if ($pluginArgs -eq $null) { return }

    # UC-3.4: DNS-01 challenge-konfiguration
    $dnsConfig = _Configure-DNS01Challenge -Plugin $plugin
    if ($dnsConfig -eq $null) { return }

    # Opsummeringsvisning
    [Console]::Clear()
    Write-Host '  === Opsummering ===' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "  Domæne:          $mainDomain" -ForegroundColor White
    if ($sans.Count -gt 0) {
        Write-Host "  SAN:             $($sans -join ', ')" -ForegroundColor White
    }
    Write-Host "  Plugin:          $plugin" -ForegroundColor White
    Write-Host "  Challenge:       DNS-01" -ForegroundColor White
    Write-Host "  DNS-sleep:       $($dnsConfig.DnsSleep) sek" -ForegroundColor White
    Write-Host "  Timeout:         $($dnsConfig.ValidationTimeout) sek" -ForegroundColor White
    $persistTxt = if ($dnsConfig.PersistentRecords) { 'Ja (records slettes ikke)' } else { 'Nej' }
    Write-Host "  Persistent DNS:  $persistTxt" -ForegroundColor $(if ($dnsConfig.PersistentRecords) { 'Yellow' } else { 'White' })
    Write-Host ''

    $confirm = Read-Host '  Bekræft bestilling? (J/N)'
    if ($confirm -notmatch '^[Jj]') { return }

    # UC-2.2: Bestil certifikat med DNS-01 trin
    $result = $null

    Write-Host ''
    Write-Host '  [ > ] Opretter DNS TXT-record...' -ForegroundColor Cyan

    try {
        $result = Show-Spinner -Message "Venter paa DNS-propagation ($($dnsConfig.DnsSleep) sek)..." -ScriptBlock {
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
        Write-Host '  [FEJL] Certifikatbestilling mislykkedes:' -ForegroundColor Red
        Write-Host "  $errMsg" -ForegroundColor Red

        if ($errMsg -match 'rateLimited|too many') {
            Write-Host ''
            Write-Host '  Tip: Du har ramt rate-limit. Skift til Staging med [F3].' -ForegroundColor Yellow
        }
        if ($errMsg -match 'DNS|TXT|propagat|timeout') {
            Write-Host ''
            Write-Host '  DNS-tip: Forøg DnsSleep til 300+ sekunder og prøv igen.' -ForegroundColor Yellow
            Write-Host '           Kontrollér at TXT-recorden er oprettet hos din DNS-provider.' -ForegroundColor Yellow
        }
        Write-Host ''
        Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
        [Console]::ReadKey($true) | Out-Null
        return
    }

    # Succes
    Write-Host ''
    Write-Host '  Certifikat bestilt!' -ForegroundColor Green
    if ($result) {
        Write-Host "  Domæne:     $($result.MainDomain)" -ForegroundColor White
        Write-Host "  Udlober:    $($result.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor White
        Write-Host "  Thumbprint: $($result.Thumbprint)" -ForegroundColor White
    }

    if ($dnsConfig.PersistentRecords) {
        Write-Host ''
        Write-Host '  Bemærk: DNS TXT-records er ikke slettet (persistent mode).' -ForegroundColor Yellow
        Write-Host '          Fjern dem manuelt hos din DNS-provider når de ikke længere bruges.' -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
    [Console]::ReadKey($true) | Out-Null
}

function _Configure-DNS01Challenge {
    param([string] $Plugin)

    $config     = Get-TUACMEConfig
    $dnsDefaults = $config.DNS

    $defaultSleep   = if ($dnsDefaults -and $dnsDefaults.DefaultDnsSleep)          { $dnsDefaults.DefaultDnsSleep }          else { 120 }
    $defaultTimeout = if ($dnsDefaults -and $dnsDefaults.DefaultValidationTimeout) { $dnsDefaults.DefaultValidationTimeout } else { 60 }
    $defaultPersist = if ($dnsDefaults -and $dnsDefaults.PersistentRecords)         { $dnsDefaults.PersistentRecords }         else { $false }

    [Console]::Clear()
    Write-Host '  === DNS-01 Challenge-indstillinger ===' -ForegroundColor Cyan
    Write-Host ''

    if ($Plugin -eq 'Manual') {
        Write-Host '  Plugin: Manual — DNS TXT-records oprettes og slettes manuelt.' -ForegroundColor Yellow
        Write-Host '  Records fjernes ikke automatisk efter validering.' -ForegroundColor DarkGray
        Write-Host ''
    }

    # DnsSleep
    Write-Host "  DNS-propagation ventetid (DnsSleep):" -ForegroundColor Gray
    Write-Host "  Standard: $defaultSleep sekunder" -ForegroundColor DarkGray
    $sleepInput = Read-Host "  Angiv sekunder (blank = $defaultSleep)"
    $dnsSleep   = $defaultSleep
    if ($sleepInput -ne '') {
        $parsed = 0
        if ([int]::TryParse($sleepInput, [ref] $parsed) -and $parsed -ge 0) {
            $dnsSleep = $parsed
        } else {
            Write-Host "  Ugyldigt tal — bruger standard ($defaultSleep sek)." -ForegroundColor Yellow
        }
    }

    Write-Host ''

    # ValidationTimeout
    Write-Host "  Valideringstimeout:" -ForegroundColor Gray
    Write-Host "  Standard: $defaultTimeout sekunder" -ForegroundColor DarkGray
    $timeoutInput      = Read-Host "  Angiv sekunder (blank = $defaultTimeout)"
    $validationTimeout = $defaultTimeout
    if ($timeoutInput -ne '') {
        $parsed = 0
        if ([int]::TryParse($timeoutInput, [ref] $parsed) -and $parsed -ge 0) {
            $validationTimeout = $parsed
        } else {
            Write-Host "  Ugyldigt tal — bruger standard ($defaultTimeout sek)." -ForegroundColor Yellow
        }
    }

    Write-Host ''

    # Persistent mode (kun relevant for non-Manual plugins)
    $persistentRecords = $defaultPersist
    if ($Plugin -ne 'Manual') {
        $persistInput = Read-Host "  Behold DNS TXT-records efter validering? (J/N, standard: $(if ($defaultPersist) { 'J' } else { 'N' }))"
        if ($persistInput -match '^[Jj]') {
            $persistentRecords = $true
            Write-Host ''
            Write-Host '  Advarsel: TXT-records forbliver synlige i DNS efter validering.' -ForegroundColor Yellow
            Write-Host '            Fjern dem manuelt hos din DNS-provider når de ikke er i brug.' -ForegroundColor Yellow
        } elseif ($persistInput -match '^[Nn]') {
            $persistentRecords = $false
        }
    }

    # Gem som nye standarder
    Write-Host ''
    $saveDefaults = Read-Host '  Gem som standard-indstillinger? (J/N)'
    if ($saveDefaults -match '^[Jj]') {
        $config.DNS = [PSCustomObject]@{
            DefaultDnsSleep          = $dnsSleep
            DefaultValidationTimeout = $validationTimeout
            PersistentRecords        = $persistentRecords
        }
        Set-TUACMEConfig -Config $config
        Write-Host '  DNS-indstillinger gemt.' -ForegroundColor Green
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
        Write-Host '  Ingen DNS-plugins fundet. Bruger Manuel validering.' -ForegroundColor Yellow
        return 'Manual'
    }

    $sel = Show-Menu -Title 'Vaelg DNS-plugin (DNS-01 challenge)' -Options $plugins -AllowSearch
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
    Write-Host "  Angiv parametre for plugin: $Plugin" -ForegroundColor Cyan

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

    # Tjek om der allerede er gemt en konto for det primære domæne
    $primaryDomain  = $Domains[0] -replace '^\*\.', ''
    $existingPath   = Get-AcmeDnsAccountPath -Domain $primaryDomain

    if ($existingPath) {
        [Console]::Clear()
        Write-Host '  === ACME-DNS ===' -ForegroundColor Cyan
        Write-Host ''
        Write-Host "  Gemt konto fundet: $existingPath" -ForegroundColor Green
        try {
            $data = Get-Content -Path $existingPath -Raw | ConvertFrom-Json
            Write-Host "  FullDomain: $($data.fulldomain)" -ForegroundColor White
        } catch {}
        Write-Host ''

        $reuse = Read-Host '  Genbrug eksisterende konto? (J/N)'
        if ($reuse -match '^[Jj]') {
            # Hent server-URL fra config
            $config = Get-TUACMEConfig
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

    # Guidet opsætning (UC-3.5)
    $result = Invoke-AcmeDnsSetup -Domains $Domains
    if ($result -eq $null) { return $null }

    # Gem server-URL i config til genbrugVed fornyelse
    $config = Get-TUACMEConfig
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
