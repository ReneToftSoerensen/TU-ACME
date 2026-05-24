function Invoke-IISMenu {
    <#
    .SYNOPSIS
        Interactive menu for inspecting and rebinding IIS HTTPS bindings
        against Posh-ACME-managed certificates.
    .DESCRIPTION
        Scans every HTTPS binding via Get-WebBinding -Protocol 'https' and
        joins each binding's certificateHash to a Posh-ACME certificate
        Thumbprint so the operator can see at a glance which sites are
        pinned to which issued cert. Offers an interactive rebind that
        swaps the current cert for another known Posh-ACME certificate
        and emits Event 1002 on success.

        Requires Windows + administrator. Always runs against the prod
        account (Use-TUACMEProdAccount) - the staging cert store is never
        consulted by this menu.
    #>
    [CmdletBinding()]
    param()

    if (-not $script:OnWindows -or -not (Get-AdminStatus)) {
        Write-Host '  IIS integration requires admin on Windows.' -ForegroundColor Yellow
        return
    }

    Use-TUACMEProdAccount

    while ($true) {
        Invoke-ConsoleClear
        Write-Host ''
        Write-Host '  === IIS integration ===' -ForegroundColor Cyan
        Write-Host ''

        $bindings = Show-Spinner -Message 'Scanning IIS bindings...' -ScriptBlock {
            @(Get-WebBinding -Protocol 'https')
        }
        if ($null -eq $bindings) { $bindings = @() }
        $bindings = @($bindings)

        $certs = @(Get-PACertificate -List)
        if ($null -eq $certs) { $certs = @() }

        # Build the join rows: every binding gets a CertSubject column
        # resolved by matching certificateHash to a Posh-ACME Thumbprint.
        $rows = @($bindings | ForEach-Object {
            $b    = $_
            $hash = $b.certificateHash
            $site = ''
            if ($b.ItemXPath) {
                $site = ($b.ItemXPath -replace ".*@name='([^']+)'.*", '$1')
            }
            $subject = '<unknown>'
            $match   = $certs | Where-Object { $_.Thumbprint -eq $hash } | Select-Object -First 1
            if ($match) { $subject = $match.Subject }
            [PSCustomObject]@{
                Site        = $site
                Binding     = $b.bindingInformation
                CertSubject = $subject
                Thumbprint  = $hash
            }
        })

        if ($rows.Count -eq 0) {
            Write-Host '  No HTTPS bindings found' -ForegroundColor Yellow
        } else {
            Show-Table `
                -Data    $rows `
                -Columns @('Site', 'Binding', 'CertSubject', 'Thumbprint')
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
                if ($rows.Count -eq 0) {
                    Write-Host '  No bindings available to rebind' -ForegroundColor Yellow
                    Read-Host 'Press Enter to continue' | Out-Null
                    continue
                }

                $site = Read-Host '  Site name'
                if ([string]::IsNullOrWhiteSpace($site)) {
                    Write-Host '  Cancelled (no site name)' -ForegroundColor Yellow
                    Read-Host 'Press Enter to continue' | Out-Null
                    continue
                }

                $siteRow = $rows | Where-Object { $_.Site -eq $site } | Select-Object -First 1
                if (-not $siteRow) {
                    Write-Host "  Unknown site '$site'" -ForegroundColor Yellow
                    Read-Host 'Press Enter to continue' | Out-Null
                    continue
                }

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
