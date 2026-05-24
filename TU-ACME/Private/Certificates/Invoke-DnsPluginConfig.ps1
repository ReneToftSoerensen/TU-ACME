function Invoke-DnsPluginConfig {
    <#
    .SYNOPSIS
        DNS plugin configuration submenu.
    .DESCRIPTION
        Lists Posh-ACME DNS plugins via Get-PAPlugin, lets the operator
        pick one, prompts for each parameter the plugin advertises
        (masking secret-named ones via Read-Host -AsSecureString), and
        persists the result through Set-PAPluginArgs which encrypts
        values under Posh-ACME's per-machine DPAPI store.

        Selecting the 'Acme-Dns' plugin routes to the dedicated
        Invoke-AcmeDnsSetup helper instead of the generic loop, since
        Acme-Dns needs the CNAME instruction flow.
    #>
    [CmdletBinding()]
    param()

    Invoke-ConsoleClear
    Write-Host '  === DNS plugin configuration ===' -ForegroundColor Cyan
    Write-Host ''

    $plugins = @(Get-PAPlugin)
    if ($plugins.Count -eq 0) {
        Write-Host '  No DNS plugins are available from Posh-ACME.' -ForegroundColor Yellow
        Read-Host '  Press Enter to continue' | Out-Null
        return
    }

    $names   = $plugins | ForEach-Object { $_.Name }
    $options = @()
    foreach ($name in $names) { $options += "$name" }
    $options += 'B. Back'

    $sel = Show-Menu -Title 'DNS plugin configuration' -Options $options
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
        Set-PAPluginArgs -Plugin $pluginName -PluginArgs $pluginArgs
        Write-Host "  Saved plugin args for $pluginName." -ForegroundColor Green
    } catch {
        Write-Host "  Failed to save: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    Read-Host '  Press Enter to continue' | Out-Null
}
