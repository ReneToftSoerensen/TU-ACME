function Invoke-OrderCertificate {
    <#
    .SYNOPSIS
        Interactive flow that orders a new certificate against the prod
        ACME account.
    .DESCRIPTION
        Switches Posh-ACME to the prod account first, prompts the
        operator for the primary domain, optional SANs, and a DNS
        plugin, then wraps New-PACertificate in Show-Spinner. Surfaces
        any Posh-ACME failure as a yellow message and emits Event 1003
        on success.

        Pressing Escape at any interactive prompt (domain, SANs, plugin,
        confirmation) cancels the order: the function prints
        "Cancelled (Esc)." and returns without calling New-PACertificate
        and without writing Event 1003.
    #>
    [CmdletBinding()]
    param()

    Use-TUACMEProdAccount

    # ---- 1. Domain prompt + validation -----------------------------------
    $domain = ''
    while ($true) {
        $domain = Read-LineOrEscape -Prompt 'Domain'
        if ($null -eq $domain) {
            Write-Host '  Cancelled (Esc).' -ForegroundColor Yellow
            return
        }
        if ($domain -match '^[a-zA-Z0-9.\-*]+$') { break }
        Write-Host '  Invalid domain. Allowed: letters, digits, dot, dash, asterisk.' -ForegroundColor Yellow
    }

    # ---- 2. Optional SAN list --------------------------------------------
    $sansRaw = Read-LineOrEscape -Prompt 'SANs (comma-separated, optional)'
    if ($null -eq $sansRaw) {
        Write-Host '  Cancelled (Esc).' -ForegroundColor Yellow
        return
    }
    $sans = @()
    if (-not [string]::IsNullOrWhiteSpace($sansRaw)) {
        $sans = @($sansRaw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    }

    # ---- 3. Plugin prompt + validation -----------------------------------
    $availablePlugins = @(Get-PAPlugin)
    $pluginNames = @($availablePlugins | ForEach-Object { $_.Name })
    $plugin = ''
    while ($true) {
        $plugin = Read-LineOrEscape -Prompt 'DNS plugin name'
        if ($null -eq $plugin) {
            Write-Host '  Cancelled (Esc).' -ForegroundColor Yellow
            return
        }
        if ($pluginNames -contains $plugin) { break }
        Write-Host "  Unknown plugin '$plugin'. Available: $($pluginNames -join ', ')" -ForegroundColor Yellow
    }

    # ---- 4. Resolve plugin args ------------------------------------------
    # Try the TU-ACME sidecar XML first (written by Invoke-DnsPluginConfig
    # via Export-Clixml — Posh-ACME 4.x has no Set-PAPluginArgs). Fall back
    # to Posh-ACME's Get-PAPluginArgs which only returns anything once an
    # order already exists, so it's useful for renewal-time calls but not
    # for the first order of a new cert.
    $pluginArgs = $null
    $sidecar = Join-Path $env:ProgramData "TU-ACME\plugin-args-$plugin.xml"
    if (Test-Path -LiteralPath $sidecar) {
        try { $pluginArgs = Import-Clixml -Path $sidecar } catch { $pluginArgs = $null }
    }
    if ($null -eq $pluginArgs -or
        ($pluginArgs -is [System.Collections.IDictionary] -and $pluginArgs.Count -eq 0)) {
        $pluginArgs = Get-PAPluginArgs $plugin
    }
    if ($null -eq $pluginArgs -or
        ($pluginArgs -is [System.Collections.IDictionary] -and $pluginArgs.Count -eq 0)) {
        Write-Host "  No saved credentials for plugin $plugin. Configure via DNS Plugins menu first." -ForegroundColor Yellow
        return
    }

    # ---- 5. Summary + confirmation ---------------------------------------
    Write-Host ''
    Write-Host '  Summary:' -ForegroundColor Cyan
    Write-Host "    Domain : $domain"
    if ($sans.Count -gt 0) {
        Write-Host "    SANs   : $($sans -join ', ')"
    } else {
        Write-Host '    SANs   : (none)'
    }
    Write-Host "    Plugin : $plugin"
    Write-Host ''

    $confirm = Read-LineOrEscape -Prompt 'Proceed? (y/N)'
    if ($null -eq $confirm) {
        Write-Host '  Cancelled (Esc).' -ForegroundColor Yellow
        return
    }
    if ($confirm -notmatch '^y$') {
        Write-Host '  Cancelled.' -ForegroundColor Yellow
        return
    }

    # ---- 6. Order under the spinner --------------------------------------
    $allNames = @($domain) + $sans
    $cert = $null
    try {
        $cert = Show-Spinner -Message "Ordering certificate for $domain..." -ScriptBlock {
            New-PACertificate -Domain $allNames -Plugin $plugin -PluginArgs $pluginArgs
        }
    } catch {
        Write-Host "  Order failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Read-Host 'Press Enter to continue' | Out-Null
        return
    }

    if ($null -eq $cert) {
        Write-Host '  Order failed: no certificate returned.' -ForegroundColor Yellow
        Read-Host 'Press Enter to continue' | Out-Null
        return
    }

    Write-EventLogEntry -EventId 1003 -EntryType Information `
        -Message "Certificate ordered: $domain (thumbprint $($cert.Thumbprint))"

    Write-Host "  Certificate issued: $($cert.Thumbprint)" -ForegroundColor Green
    Read-Host 'Press Enter to continue' | Out-Null
}
