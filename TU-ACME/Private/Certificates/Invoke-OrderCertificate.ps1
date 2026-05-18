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

    # UC-3.2 + 3.3: Indsaml plugin-parametre
    $pluginArgs = _Collect-PluginArgs -Plugin $plugin
    if ($pluginArgs -eq $null) { return }

    # Opsummeringsvisning
    [Console]::Clear()
    Write-Host '  === Opsummering ===' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "  Domæne:   $mainDomain" -ForegroundColor White
    if ($sans.Count -gt 0) {
        Write-Host "  SAN:      $($sans -join ', ')" -ForegroundColor White
    }
    Write-Host "  Plugin:   $plugin" -ForegroundColor White
    Write-Host ''

    $confirm = Read-Host '  Bekræft bestilling? (J/N)'
    if ($confirm -notmatch '^[Jj]') { return }

    # UC-2.2: Bestil certifikat med spinner
    $allDomains = @($mainDomain) + $sans
    $result     = $null

    try {
        $result = Show-Spinner -Message "Bestiller certifikat for $mainDomain ..." -ScriptBlock {
            $certParams = @{
                Domain     = $allDomains
                Plugin     = $plugin
                PluginArgs = $pluginArgs
                AcceptTOS  = $true
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
            Write-Host '  Tip: Du har ramte rate-limit. Skift til Staging med [F3].' -ForegroundColor Yellow
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
    Write-Host ''
    Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
    [Console]::ReadKey($true) | Out-Null
}

function _Select-DNSPlugin {
    $plugins = @()
    try {
        $plugins = @(Get-PAPlugin 2>$null | Select-Object -ExpandProperty Plugin)
    } catch {}

    if ($plugins.Count -eq 0) {
        # Fallback: brug Manual
        Write-Host '  Ingen DNS-plugins fundet. Bruger Manuel validering.' -ForegroundColor Yellow
        return 'Manual'
    }

    $sel = Show-Menu -Title 'Vaelg DNS-plugin' -Options $plugins -AllowSearch
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
