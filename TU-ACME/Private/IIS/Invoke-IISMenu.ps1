function Invoke-IISMenu {
    <#
    .SYNOPSIS
        Interactive menu for inspecting and rebinding IIS bindings against
        Posh-ACME-managed certificates.
    .DESCRIPTION
        Scans every binding via Get-WebBinding (both HTTP and HTTPS — HTTP
        rows are listed for operational visibility; only HTTPS rows can be
        rebound). For each HTTPS binding the cert is looked up in
        Cert:\LocalMachine\My by Thumbprint and the row is enriched with:
          * Subject  — from the X509Certificate2
          * Expires  — NotAfter (yyyy-MM-dd)
          * Template — AD CS template name (v1 or v2 extension); blank for
                       certs without an AD-CS template (e.g. Let's Encrypt
                       or an externally-issued cert).

        The rebind picker filters to HTTPS rows so the operator can't pick
        an HTTP binding to swap a thumbprint onto (HTTP bindings have no
        certificateHash to set).

        Requires Windows + administrator. Always runs against the prod
        account (Use-TUACMEProdAccount); the staging cert store is never
        consulted by this menu.
    #>
    [CmdletBinding()]
    param()

    if (-not $script:OnWindows -or -not (Get-AdminStatus)) {
        Write-Host '  IIS integration requires admin on Windows.' -ForegroundColor Yellow
        return
    }

    try {
        Import-Module WebAdministration -ErrorAction Stop
    } catch {
        Write-Host '  IIS integration requires the WebAdministration module (IIS not installed).' -ForegroundColor Yellow
        return
    }

    Use-TUACMEProdAccount

    while ($true) {
        Invoke-ConsoleClear
        Write-Host ''
        Write-Host '  === IIS integration ===' -ForegroundColor Cyan
        Write-Host ''

        # No -Protocol filter: surface every binding so the operator can
        # see HTTP-only sites alongside HTTPS ones.
        $bindings = Show-Spinner -Message 'Scanning IIS bindings...' -ScriptBlock {
            @(Get-WebBinding)
        }
        if ($null -eq $bindings) { $bindings = @() }
        $bindings = @($bindings)

        $certs = @(Get-PACertificate -List)
        if ($null -eq $certs) { $certs = @() }

        # Cache cert lookups within a single render pass so we don't hit
        # Cert:\LocalMachine\My twice for the same thumbprint when a cert
        # is bound to several sites.
        $certCache = @{}

        $rows = @($bindings | ForEach-Object {
            $b    = $_
            $proto = if ($b.protocol) { $b.protocol } else { '' }
            $hash  = if ($b.certificateHash) { $b.certificateHash } else { '' }

            $site = ''
            if ($b.ItemXPath) {
                $site = ($b.ItemXPath -replace ".*@name='([^']+)'.*", '$1')
            }

            $subject  = ''
            $expires  = ''
            $template = ''

            if ($proto -eq 'https' -and -not [string]::IsNullOrWhiteSpace($hash)) {
                # Prefer the Posh-ACME Subject string (cheap, no Cert: hit)
                # but always look the X509Certificate2 up for NotAfter and
                # the template extension.
                $paMatch = $certs | Where-Object { $_.Thumbprint -eq $hash } | Select-Object -First 1
                if ($paMatch -and $paMatch.Subject) { $subject = $paMatch.Subject }

                if ($certCache.ContainsKey($hash)) {
                    $x509 = $certCache[$hash]
                } else {
                    $x509 = $null
                    # String concat instead of Join-Path so a host without
                    # the Cert: provider (Linux PS 7, CI) fails inside the
                    # silenced Test-Path rather than blowing up on path
                    # construction. Posh-ACME-managed certs always live in
                    # LocalMachine\My once deployed, so the path is fixed.
                    try {
                        $path = "Cert:\LocalMachine\My\$hash"
                        if (Test-Path $path -ErrorAction SilentlyContinue) {
                            $x509 = Get-Item $path -ErrorAction SilentlyContinue
                        }
                    } catch { $x509 = $null }
                    $certCache[$hash] = $x509
                }

                if ($x509) {
                    if (-not $subject) { $subject = $x509.Subject }
                    if ($x509.NotAfter) {
                        $expires = (Get-Date $x509.NotAfter -Format 'yyyy-MM-dd')
                    }
                    $template = Get-CertTemplateName -Certificate $x509
                }

                if (-not $subject) { $subject = '<unknown>' }
            }

            [PSCustomObject]@{
                Site        = $site
                Protocol    = $proto
                Binding     = $b.bindingInformation
                # Kept under the old column name so UC-9.03 still passes
                # and downstream callers don't break — same value, same
                # rendering role.
                CertSubject = $subject
                Expires     = $expires
                Template    = $template
                Thumbprint  = $hash
            }
        })

        if ($rows.Count -eq 0) {
            Write-Host '  No bindings found' -ForegroundColor Yellow
        } else {
            Show-Table `
                -Data    $rows `
                -Columns @('Site', 'Protocol', 'Binding', 'CertSubject', 'Expires', 'Template', 'Thumbprint') `
                -Headers @('Site', 'Proto',    'Binding', 'Subject',     'Expires', 'Template', 'Thumbprint') `
                -Widths  @(22,     6,          28,        24,            12,        14,         12)
        }

        Write-Host ''

        $options = @(
            '1. Rebind a site',
            '2. Refresh',
            'B. Back'
        )

        $selection = Show-Menu -Title 'TU-ACME - IIS integration' -Options $options

        switch ($selection) {
            0 {
                # Rebind only operates on HTTPS rows — HTTP bindings have
                # no certificateHash to set.
                $httpsRows = @($rows | Where-Object { $_.Protocol -eq 'https' })
                if ($httpsRows.Count -eq 0) {
                    Write-Host '  No HTTPS bindings available to rebind' -ForegroundColor Yellow
                    Read-Host 'Press Enter to continue' | Out-Null
                    continue
                }

                $pickerOptions = @()
                for ($r = 0; $r -lt $httpsRows.Count; $r++) {
                    $row   = $httpsRows[$r]
                    $parts = $row.Binding -split ':', 3
                    $hn    = if ($parts.Count -ge 3) { $parts[2] } else { '' }
                    if ([string]::IsNullOrWhiteSpace($hn)) { $hn = '<no hostname>' }
                    $pickerOptions += ('{0}. {1} - {2}' -f ($r + 1), $row.Site, $hn)
                }
                $pickerOptions += 'B. Back'

                $pickIdx = Show-Menu -Title 'TU-ACME - Pick a binding to rebind' `
                                     -Options $pickerOptions -AllowSearch
                if ($pickIdx -eq -1 -or $pickIdx -eq ($pickerOptions.Count - 1)) {
                    continue
                }

                $siteRow = $httpsRows[$pickIdx]
                $site    = $siteRow.Site

                if ($certs.Count -eq 0) {
                    Write-Host '  No Posh-ACME certificates available' -ForegroundColor Yellow
                    Read-Host 'Press Enter to continue' | Out-Null
                    continue
                }

                Write-Host ''
                Write-Host '  Available certificates:' -ForegroundColor Cyan
                for ($i = 0; $i -lt $certs.Count; $i++) {
                    Write-Host ("    {0}. {1}  ({2})" -f ($i + 1), $certs[$i].Subject, $certs[$i].Thumbprint)
                }
                Write-Host ''

                $pick = Read-Host '  Certificate number'
                $pickIndex = 0
                if (-not [int]::TryParse($pick, [ref]$pickIndex) -or
                    $pickIndex -lt 1 -or $pickIndex -gt $certs.Count) {
                    Write-Host '  Invalid selection' -ForegroundColor Yellow
                    Read-Host 'Press Enter to continue' | Out-Null
                    continue
                }

                $newThumbprint = $certs[$pickIndex - 1].Thumbprint

                try {
                    Set-WebBinding -Name $site `
                        -BindingInformation $siteRow.Binding `
                        -PropertyName 'certificateHash' `
                        -Value $newThumbprint
                } catch {
                    Write-Host "  Rebind failed: $($_.Exception.Message)" -ForegroundColor Yellow
                    Read-Host 'Press Enter to continue' | Out-Null
                    continue
                }

                Write-EventLogEntry -EventId 1002 -EntryType Information `
                    -Message ("IIS binding refreshed: site='{0}' binding='{1}' thumbprint={2}" `
                        -f $site, $siteRow.Binding, $newThumbprint)

                Write-Host "  Rebound $site to $newThumbprint" -ForegroundColor Green
                Read-Host 'Press Enter to continue' | Out-Null
            }
            1 {
                # Refresh: just loop.
                continue
            }
            2       { return }
            -1      { return }
            default { return }
        }
    }
}
