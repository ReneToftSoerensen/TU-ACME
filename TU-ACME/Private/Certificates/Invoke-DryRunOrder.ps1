function Invoke-DryRunOrder {
    <#
    .SYNOPSIS
        Dry-run certificate order against the staging account.
    .DESCRIPTION
        The one and only TUI flow that switches Posh-ACME to the staging
        account. Prompts for domain, SANs and DNS plugin, orders a cert
        via New-PACertificate, tags the resulting order with
        FriendlyName 'TU-ACME-DryRun' so the dashboard can filter it out,
        and emits Event 1006 on success. Regardless of outcome, the
        finally block restores the prod account so subsequent flows
        never accidentally hit staging.
    #>
    [CmdletBinding()]
    param()

    Invoke-ConsoleClear
    Write-Host ''
    Write-Host '  === Dry-run order (staging) ===' -ForegroundColor Cyan
    Write-Host ''

    Use-TUACMEStagingAccount
    try {
        # Prompt and validate domain (loop until it matches the allowed shape)
        $Domain = ''
        while ([string]::IsNullOrWhiteSpace($Domain) -or ($Domain -notmatch '^[a-zA-Z0-9.\-*]+$')) {
            $Domain = Read-Host '  Domain (e.g. www.example.com)'
            if ([string]::IsNullOrWhiteSpace($Domain) -or ($Domain -notmatch '^[a-zA-Z0-9.\-*]+$')) {
                Write-Host '  Invalid domain. Use letters, digits, dot, hyphen or wildcard *.' -ForegroundColor Yellow
            }
        }

        # Optional SANs (comma-separated, empty allowed)
        $sansInput = Read-Host '  Additional SANs (comma-separated, optional)'
        $Sans = @()
        if (-not [string]::IsNullOrWhiteSpace($sansInput)) {
            $Sans = $sansInput.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        }

        # DNS plugin and plugin args. Plugin args for the current order
        # are sourced from Posh-ACME's per-order store (populated by
        # Set-PAPluginArgs / first-time prompts); Get-PAPluginArgs with
        # no arguments returns the active hashtable.
        $Plugin = Read-Host '  DNS plugin name'
        $PluginArgs = Get-PAPluginArgs

        # Summary and confirmation (default No)
        Write-Host ''
        Write-Host '  --- Dry-run summary ---' -ForegroundColor DarkCyan
        Write-Host "    Domain : $Domain"
        if ($Sans.Count -gt 0) {
            Write-Host "    SANs   : $($Sans -join ', ')"
        }
        Write-Host "    Plugin : $Plugin"
        Write-Host ''
        $confirm = Read-Host '  Proceed with dry-run order? (y/N)'
        if ($confirm -notmatch '^[Yy]') {
            Write-Host '  Dry-run cancelled.' -ForegroundColor Yellow
            return
        }

        # Build the names list for New-PACertificate
        $names = @($Domain) + $Sans

        $cert = $null
        $orderError = $null
        $cert = Show-Spinner -Message "Ordering dry-run certificate for $Domain ..." -ScriptBlock {
            try {
                New-PACertificate -Domain $names -Plugin $Plugin -PluginArgs $PluginArgs -Force
            } catch {
                $script:_dryRunOrderError = $_
                throw
            }
        }

        if ($null -ne $cert) {
            try {
                Set-PAOrder -FriendlyName 'TU-ACME-DryRun'
            } catch {
                Write-Host "  Warning: could not tag dry-run order: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            $thumb = $null
            try { $thumb = $cert.Thumbprint } catch { $thumb = '' }
            Write-EventLogEntry -EventId 1006 -EntryType Information `
                -Message "Dry-run cert issued for $Domain (thumbprint $thumb)"
            Write-Host ''
            Write-Host "  Dry-run cert issued for $Domain (thumbprint $thumb)" -ForegroundColor Green
        }
    } catch {
        Write-Host ''
        Write-Host "  Dry-run order failed: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        # Critical: switch back to prod even on error so that subsequent
        # flows do not accidentally hit staging.
        Use-TUACMEProdAccount
    }
}
