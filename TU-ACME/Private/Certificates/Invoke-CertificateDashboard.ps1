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
            Write-Host '  Press any key...' -ForegroundColor DarkGray
            Invoke-ConsoleWaitKey
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
    Write-Host '  [E] Export  [R] Renew now  [ESC] Back' -ForegroundColor DarkGray

    while ($true) {
        $key = Invoke-ConsoleReadKey
        switch ($key.Key) {
            ([ConsoleKey]::Escape) { return }
            default {
                switch ($key.KeyChar) {
                    'e' { Invoke-ExportMenu -Cert $Cert; return }
                    'E' { Invoke-ExportMenu -Cert $Cert; return }
                    'r' {
                        Write-Host '  Renewal starting...' -ForegroundColor Cyan
                        try {
                            Submit-Renewal -MainDomain $Cert.MainDomain -Force | Out-Null
                            Write-Host '  Renewal completed.' -ForegroundColor Green
                        } catch {
                            Write-Host "  Error: $_" -ForegroundColor Red
                        }
                        Write-Host '  Press any key...' -ForegroundColor DarkGray
                        Invoke-ConsoleWaitKey
                        return
                    }
                    'R' {
                        Write-Host '  Renewal starting...' -ForegroundColor Cyan
                        try {
                            Submit-Renewal -MainDomain $Cert.MainDomain -Force | Out-Null
                            Write-Host '  Renewal completed.' -ForegroundColor Green
                        } catch {
                            Write-Host "  Error: $_" -ForegroundColor Red
                        }
                        Write-Host '  Press any key...' -ForegroundColor DarkGray
                        Invoke-ConsoleWaitKey
                        return
                    }
                }
            }
        }
    }
}
