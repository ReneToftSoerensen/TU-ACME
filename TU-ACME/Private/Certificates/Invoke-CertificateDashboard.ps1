function Invoke-CertificateDashboard {
    $warnDays = (Get-TUACMEConfig).Dashboard.WarnDaysThreshold

    while ($true) {
        $certs = @(Get-PACertificate -List 2>$null)
        Invoke-ConsoleClear

        Write-Host '  === Certificate Dashboard ===' -ForegroundColor Cyan
        Write-Host "  Warning when less than $warnDays days until expiry" -ForegroundColor DarkGray
        Write-Host ''

        if ($certs.Count -eq 0) {
            Write-Host '  No certificates found.' -ForegroundColor Yellow
            Write-Host '  Use "Order new certificate" to get started.' -ForegroundColor DarkGray
            Write-Host ''
            Wait-AnyKey
            return
        }

        # Add a calculated DaysLeft to each object
        $rows = $certs | ForEach-Object {
            $days = if ($_.NotAfter) {
                [int](($_.NotAfter - (Get-Date)).TotalDays)
            } else { -1 }
            [PSCustomObject]@{
                Domain   = $_.MainDomain
                Expires  = if ($_.NotAfter) { $_.NotAfter.ToString('yyyy-MM-dd') } else { 'Unknown' }
                DaysLeft = $days
                Status   = if ($days -lt 0) { 'EXPIRED' } elseif ($days -le $warnDays) { 'Warning' } else { 'OK' }
                Thumbprint = if ($_.Thumbprint) { $_.Thumbprint.Substring(0, [Math]::Min(16, $_.Thumbprint.Length)) + '...' } else { '' }
            }
        }

        $colorRule = {
            param($row)
            if ($row.DaysLeft -lt 0)          { 'Red' }
            elseif ($row.DaysLeft -le $warnDays) { 'Yellow' }
            else                               { 'Green' }
        }

        $sel = Show-Table -Data $rows `
            -Columns @('Domain', 'Expires', 'DaysLeft', 'Status') `
            -Headers @('Domain', 'Expires', 'Days', 'Status') `
            -Widths  @(30, 12, 6, 10) `
            -ColorRule $colorRule `
            -Interactive

        if ($sel -lt 0) { return }

        # Show details for the selected certificate
        _Show-CertDetail -Cert $certs[$sel] -DaysLeft $rows[$sel].DaysLeft
    }
}

function _Show-CertDetail {
    param($Cert, [int] $DaysLeft)

    Invoke-ConsoleClear
    Write-Host '  === Certificate Details ===' -ForegroundColor Cyan
    Write-Host ''

    $fields = [ordered]@{
        'Domain (CN)'      = $Cert.MainDomain
        'SAN domains'      = ($Cert.SANs -join ', ')
        'Issuer'           = $Cert.Issuer
        'Issued'           = if ($Cert.NotBefore) { $Cert.NotBefore.ToString('yyyy-MM-dd') } else { '' }
        'Expires'          = if ($Cert.NotAfter)  { $Cert.NotAfter.ToString('yyyy-MM-dd') }  else { '' }
        'Days remaining'   = $DaysLeft
        'Thumbprint'       = $Cert.Thumbprint
        'Key Length'       = $Cert.KeyLength
        'DNS plugin'       = $Cert.Plugin
        'Renewal'          = $Cert.RenewAfter
        'Certificate file' = $Cert.CertFile
        'Key file'         = $Cert.KeyFile
    }

    foreach ($kv in $fields.GetEnumerator()) {
        Write-Host "  $($kv.Key.PadRight(18)): " -ForegroundColor Gray -NoNewline
        Write-Host "$($kv.Value)" -ForegroundColor White
    }

    Write-Host ''
    Write-Host '  [E] Export  [R] Renew now  [D] Delete  [ESC] Back' -ForegroundColor DarkGray

    while ($true) {
        $key = Invoke-ConsoleReadKey
        if ($key.Key -eq [ConsoleKey]::Escape) { return }
        switch -Regex ($key.KeyChar.ToString()) {
            '^[Ee]$' { Invoke-ExportMenu -Cert $Cert; return }
            '^[Rr]$' {
                Write-Host '  Renewal starting...' -ForegroundColor Cyan
                try {
                    Submit-Renewal -MainDomain $Cert.MainDomain -Force | Out-Null
                    Write-Host '  Renewal completed.' -ForegroundColor Green
                } catch {
                    Write-Host "  Error: $_" -ForegroundColor Red
                }
                Wait-AnyKey
                return
            }
            '^[Dd]$' {
                Write-Host ''
                Write-Host "  Delete certificate for '$($Cert.MainDomain)' from the Posh-ACME store?" -ForegroundColor Yellow
                Write-Host '  This removes the local certificate, key, and renewal config.' -ForegroundColor DarkGray
                Write-Host '  The ACME order itself is unaffected; the cert is not revoked.' -ForegroundColor DarkGray
                Write-Host ''
                if (Confirm-YesNo '  Confirm delete? (y/N)' -Default $false) {
                    try {
                        Remove-PACertificate -MainDomain $Cert.MainDomain -Force
                        Write-Host '  Certificate removed.' -ForegroundColor Green
                        Write-EventLogEntry -EventId 1003 -EntryType Information `
                            -Message "TU-ACME: Removed certificate $($Cert.MainDomain)"
                    } catch {
                        Write-Host "  Error: $_" -ForegroundColor Red
                    }
                    Wait-AnyKey
                }
                return
            }
        }
    }
}
