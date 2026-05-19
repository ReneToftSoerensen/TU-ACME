function Invoke-CertificateDashboard {
    $warnDays = (Get-TUACMEConfig).Dashboard.WarnDaysThreshold

    while ($true) {
        $certs = @(Get-PACertificate -List 2>$null)
        [Console]::Clear()

        Write-Host '  === Certifikat-dashboard ===' -ForegroundColor Cyan
        Write-Host "  Advarsel ved under $warnDays dage til udloeb" -ForegroundColor DarkGray
        Write-Host ''

        if ($certs.Count -eq 0) {
            Write-Host '  Ingen certifikater fundet.' -ForegroundColor Yellow
            Write-Host '  Brug "Bestil nyt certifikat" for at komme i gang.' -ForegroundColor DarkGray
            Write-Host ''
            Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
            [Console]::ReadKey($true) | Out-Null
            return
        }

        # Tilfoej beregnet DaysLeft til hvert objekt
        $rows = $certs | ForEach-Object {
            $days = if ($_.NotAfter) {
                [int](($_.NotAfter - (Get-Date)).TotalDays)
            } else { -1 }
            [PSCustomObject]@{
                Domain   = $_.MainDomain
                Udlober  = if ($_.NotAfter) { $_.NotAfter.ToString('yyyy-MM-dd') } else { 'Ukendt' }
                DaysLeft = $days
                Status   = if ($days -lt 0) { 'UDLOBET' } elseif ($days -le $warnDays) { 'Advarer' } else { 'OK' }
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
            -Columns @('Domain', 'Udlober', 'DaysLeft', 'Status') `
            -Headers @('Domæne', 'Udloeber', 'Dage', 'Status') `
            -Widths  @(30, 12, 6, 10) `
            -ColorRule $colorRule `
            -Interactive

        if ($sel -lt 0) { return }

        # Vis detaljer for valgt certifikat
        _Show-CertDetail -Cert $certs[$sel] -DaysLeft $rows[$sel].DaysLeft
    }
}

function _Show-CertDetail {
    param($Cert, [int] $DaysLeft)

    [Console]::Clear()
    Write-Host '  === Certifikat-detaljer ===' -ForegroundColor Cyan
    Write-Host ''

    $fields = [ordered]@{
        'Domæne (CN)'     = $Cert.MainDomain
        'SAN-domæner'     = ($Cert.SANs -join ', ')
        'Udsteder'        = $Cert.Issuer
        'Udstedes'        = if ($Cert.NotBefore) { $Cert.NotBefore.ToString('yyyy-MM-dd') } else { '' }
        'Udlober'         = if ($Cert.NotAfter)  { $Cert.NotAfter.ToString('yyyy-MM-dd') }  else { '' }
        'Dage tilbage'    = $DaysLeft
        'Thumbprint'      = $Cert.Thumbprint
        'Key Length'      = $Cert.KeyLength
        'DNS-plugin'      = $Cert.Plugin
        'Fornyelse'       = $Cert.RenewAfter
        'Certifikat-fil'  = $Cert.CertFile
        'Noegle-fil'      = $Cert.KeyFile
    }

    foreach ($kv in $fields.GetEnumerator()) {
        Write-Host "  $($kv.Key.PadRight(18)): " -ForegroundColor Gray -NoNewline
        Write-Host "$($kv.Value)" -ForegroundColor White
    }

    Write-Host ''
    Write-Host '  [E] Eksporter  [R] Forny nu  [ESC] Tilbage' -ForegroundColor DarkGray

    while ($true) {
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            ([ConsoleKey]::Escape) { return }
            default {
                switch ($key.KeyChar) {
                    'e' { Invoke-ExportMenu -Cert $Cert; return }
                    'E' { Invoke-ExportMenu -Cert $Cert; return }
                    'r' {
                        Write-Host '  Fornyelse starter...' -ForegroundColor Cyan
                        try {
                            Submit-Renewal -MainDomain $Cert.MainDomain -Force | Out-Null
                            Write-Host '  Fornyelse gennemfoert.' -ForegroundColor Green
                        } catch {
                            Write-Host "  Fejl: $_" -ForegroundColor Red
                        }
                        Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
                        [Console]::ReadKey($true) | Out-Null
                        return
                    }
                    'R' {
                        Write-Host '  Fornyelse starter...' -ForegroundColor Cyan
                        try {
                            Submit-Renewal -MainDomain $Cert.MainDomain -Force | Out-Null
                            Write-Host '  Fornyelse gennemfoert.' -ForegroundColor Green
                        } catch {
                            Write-Host "  Fejl: $_" -ForegroundColor Red
                        }
                        Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
                        [Console]::ReadKey($true) | Out-Null
                        return
                    }
                }
            }
        }
    }
}
