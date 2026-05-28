function Invoke-DnsPluginConfig {
    <#
    .SYNOPSIS
        Posh-ACME plugin configuration submenu.
    .DESCRIPTION
        Posh-ACME 4.32 ships roughly one hundred plugins. Rendering them
        as a flat Show-Menu blew past the visible screen and gave no hint
        about which plugin handled which ACME challenge type. This helper
        instead drives a two-tier flow:

        1. First tier: pick a challenge type bucket
           (DNS-01, HTTP-01, Back).
        2. Second tier: pick a plugin from the bucket; Show-Menu is
           invoked with -AllowSearch so the operator can type '/' to
           filter the long list by name.

        Each plugin's challenge type is sourced from its
        Get-CurrentPluginType function. We try the ChallengeType property
        that Posh-ACME 4.x already exposes on Get-PAPlugin, and fall back
        to a one-shot scan of the Plugins\ directory when an older or
        forked Posh-ACME doesn't expose it. The cache is built once at
        function entry; discovery is cheap (~100 small files).

        Selecting the 'Acme-Dns' plugin routes to the dedicated
        Invoke-AcmeDnsSetup helper instead of the generic loop, since
        Acme-Dns needs the CNAME instruction flow. All other plugins
        follow the generic Get-PAPlugin -Params loop and persist a
        hashtable via Export-Clixml to
        %ProgramData%\TU-ACME\plugin-args-<plugin>.xml, which the order
        flow merges into -PluginArgs at New-PACertificate time.
    #>
    [CmdletBinding()]
    param()

    Invoke-ConsoleClear
    Write-Host '  === Plugin configuration ===' -ForegroundColor Cyan
    Write-Host ''

    $allPlugins = @(Get-PAPlugin)
    if ($allPlugins.Count -eq 0) {
        Write-Host '  No plugins are available from Posh-ACME.' -ForegroundColor Yellow
        Read-Host '  Press Enter to continue' | Out-Null
        return
    }

    # Build name -> ChallengeType cache. Prefer the property on the list
    # object (Posh-ACME 4.x already exposes it); only fall back to a
    # directory scan when at least one entry is missing the property or
    # has it empty.
    $typeByName = @{}
    foreach ($p in $allPlugins) {
        $name = $p.Name
        $ct   = $null
        if ($p.PSObject.Properties['ChallengeType']) {
            $ct = $p.ChallengeType
        }
        if (-not [string]::IsNullOrEmpty($ct)) {
            $typeByName[$name] = $ct
        }
    }
    if ($typeByName.Count -lt $allPlugins.Count) {
        # Fallback: scan Posh-ACME's Plugins directory for the
        # Get-CurrentPluginType literal each plugin declares.
        try {
            $module = Get-Module Posh-ACME
            if ($null -ne $module) {
                $pluginsDir = Join-Path $module.ModuleBase 'Plugins'
                if (Test-Path $pluginsDir) {
                    $files = @(Get-ChildItem -Path $pluginsDir -Filter '*.ps1' -ErrorAction SilentlyContinue)
                    foreach ($file in $files) {
                        $name = $file.BaseName
                        if ($typeByName.ContainsKey($name)) { continue }
                        $content = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
                        if ($null -ne $content -and $content -match "function\s+Get-CurrentPluginType\s*\{\s*'([\w\-]+)'\s*\}") {
                            $typeByName[$name] = $matches[1]
                        }
                    }
                }
            }
        } catch {
            # Discovery is best-effort; plugins without a known type land
            # nowhere and are simply unreachable from the menu.
        }
    }

    # First-tier challenge-type picker. Posh-ACME 4.32 only accepts
    # 'dns-01' or 'http-01' as plugin challenge types — anything else
    # is rejected by Import-PluginDetail. "Persistent" behavior in
    # DNS-01 plugins (e.g. Cloudflare leaves TXT records via its API)
    # is a runtime detail of the plugin's implementation, not a
    # selectable type, so the menu only surfaces the two real buckets.
    $tierOptions = @(
        '1. DNS-01 plugins',
        '2. HTTP-01 plugins',
        'B. Back'
    )
    $tierSel = Show-Menu -Title 'Plugin configuration' -Options $tierOptions
    if ($tierSel -eq -1 -or $tierSel -eq ($tierOptions.Count - 1)) { return }

    switch ($tierSel) {
        0 { $wantedType = 'dns-01';  $tierTitle = 'DNS-01 plugins' }
        1 { $wantedType = 'http-01'; $tierTitle = 'HTTP-01 plugins' }
        default { return }
    }

    $names = @(
        $allPlugins |
            Where-Object { $typeByName[$_.Name] -eq $wantedType } |
            ForEach-Object { $_.Name } |
            Sort-Object
    )

    if ($names.Count -eq 0) {
        Invoke-ConsoleClear
        Write-Host "  === $tierTitle ===" -ForegroundColor Cyan
        Write-Host ''
        Write-Host "  No plugins of type '$wantedType' are installed." -ForegroundColor Yellow
        Read-Host '  Press Enter to continue' | Out-Null
        return
    }

    # Second-tier plugin picker, AllowSearch so '/' filters the long list.
    $options = @()
    foreach ($n in $names) { $options += "$n" }
    $options += 'B. Back'

    $sel = Show-Menu -Title $tierTitle -Options $options -AllowSearch
    if ($sel -eq -1 -or $sel -eq ($options.Count - 1)) { return }

    $pluginName = $names[$sel]

    # Acme-Dns shortcut routes to the dedicated helper.
    if ($pluginName -match '^(?i)acme-dns$') {
        Invoke-AcmeDnsSetup | Out-Null
        Read-Host '  Press Enter to continue' | Out-Null
        return
    }

    $paramInfo = @(Get-PAPlugin -Plugin $pluginName -Params)

    $pluginArgs = @{}
    foreach ($p in $paramInfo) {
        $paramName = $p.Name
        $isSecret  = $paramName -match '(?i)key|password|token|secret'
        $mandatory = $false
        if ($p.PSObject.Properties['Mandatory']) {
            $mandatory = [bool]$p.Mandatory
        }

        $label = "  $paramName"
        if ($mandatory) { $label = "$label (required)" }

        if ($isSecret) {
            $value = Read-Host -Prompt $label -AsSecureString
            if ($null -ne $value -and $value.Length -gt 0) {
                $pluginArgs[$paramName] = $value
            }
        } else {
            $value = Read-Host -Prompt $label
            if ($value -ne '') {
                $pluginArgs[$paramName] = $value
            }
        }
    }

    Write-Host ''
    $confirm = Read-Host '  Save these credentials? (y/N)'
    if ($confirm -notmatch '^(?i)y$') {
        Write-Host '  Cancelled.' -ForegroundColor Yellow
        Read-Host '  Press Enter to continue' | Out-Null
        return
    }

    try {
        $sidecarDir = Join-Path $env:ProgramData 'TU-ACME'
        if (-not (Test-Path $sidecarDir)) {
            New-Item -ItemType Directory -Path $sidecarDir -Force | Out-Null
        }
        $sidecar = Join-Path $sidecarDir ("plugin-args-$pluginName.xml")
        $pluginArgs | Export-Clixml -Path $sidecar
        Write-Host "  Saved plugin args for $pluginName." -ForegroundColor Green
    } catch {
        Write-Host "  Failed to save: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    Read-Host '  Press Enter to continue' | Out-Null
}
