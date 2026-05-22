function Invoke-CertificateDashboard {
    $warnDays = (Get-TUACMEConfig).Dashboard.WarnDaysThreshold

    # The dashboard aggregates certs across ALL Posh-ACME servers, not
    # just the active one. Detail-view actions (renew/delete) switch
    # the active server+account to match the selected cert; remember
    # the entry context so we can put it back when the user exits.
    $entryServer  = $null
    $entryAccount = $null
    try { $entryServer  = Get-PAServer  -ErrorAction SilentlyContinue } catch {}
    try { $entryAccount = Get-PAAccount -ErrorAction SilentlyContinue } catch {}

    try {
        while ($true) {
            $certs = @(Get-TUACMEAllCertificates)
            Invoke-ConsoleClear

            Write-Host '  === Certificate Dashboard ===' -ForegroundColor Cyan
            Write-Host "  Warning when less than $warnDays days until expiry" -ForegroundColor DarkGray
            Write-Host '  Showing certificates from all Posh-ACME servers' -ForegroundColor DarkGray
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
                    Domain   = _Get-TUACMECertDisplayName -Cert $_
                    Server   = if ($_.ServerName) { $_.ServerName } else { '(unknown)' }
                    Expires  = if ($_.NotAfter) { $_.NotAfter.ToString('yyyy-MM-dd') } else { 'Unknown' }
                    DaysLeft = $days
                    Status   = if ($days -lt 0) { 'EXPIRED' } elseif ($days -le $warnDays) { 'Warning' } else { 'OK' }
                }
            }

            $colorRule = {
                param($row)
                if ($row.DaysLeft -lt 0)          { 'Red' }
                elseif ($row.DaysLeft -le $warnDays) { 'Yellow' }
                else                               { 'Green' }
            }

            $sel = Show-Table -Data $rows `
                -Columns @('Domain', 'Server', 'Expires', 'DaysLeft', 'Status') `
                -Headers @('Domain', 'Server', 'Expires', 'Days', 'Status') `
                -Widths  @(28, 14, 12, 6, 10) `
                -ColorRule $colorRule `
                -Interactive

            if ($sel -lt 0) { return }

            # Show details for the selected certificate
            _Show-CertDetail -Cert $certs[$sel] -DaysLeft $rows[$sel].DaysLeft
        }
    } finally {
        # Restore the active server+account that was in effect when the
        # dashboard was entered (renew/delete may have switched it).
        if ($entryServer -and $entryServer.Name) {
            try { Set-PAServer $entryServer.Name -ErrorAction SilentlyContinue } catch {}
        }
        if ($entryAccount -and $entryAccount.id) {
            try { Set-PAAccount -ID $entryAccount.id -ErrorAction SilentlyContinue } catch {}
        }
    }
}

function _Show-CertDetail {
    param($Cert, [int] $DaysLeft)

    Invoke-ConsoleClear
    Write-Host '  === Certificate Details ===' -ForegroundColor Cyan
    Write-Host ''

    $fields = [ordered]@{
        'Domain (CN)'      = _Get-TUACMECertDisplayName -Cert $Cert
        'Server'           = if ($Cert.ServerName) { $Cert.ServerName } else { '(active)' }
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
    Write-Host '  [E] Export  [R] Renew  [F] Force renew (new key)  [V] Revoke  [D] Delete  [ESC] Back' -ForegroundColor DarkGray

    while ($true) {
        $key = Invoke-ConsoleReadKey
        if ($key.Key -eq [ConsoleKey]::Escape) { return }
        switch -Regex ($key.KeyChar.ToString()) {
            '^[Ee]$' { Invoke-ExportMenu -Cert $Cert; return }
            '^[Rr]$' {
                Write-Host '  Renewal starting...' -ForegroundColor Cyan
                try {
                    _Switch-PAContext -Cert $Cert
                    Submit-Renewal -MainDomain $Cert.MainDomain -Force | Out-Null
                    Write-Host '  Renewal completed.' -ForegroundColor Green
                } catch {
                    Write-Host "  Error: $_" -ForegroundColor Red
                }
                Wait-AnyKey
                return
            }
            '^[Ff]$' {
                # Force a renewal that also rotates the private key —
                # the typical post-leak recovery. Set-PAOrder -NewKey
                # flags the order so Submit-Renewal regenerates the key.
                $displayName = _Get-TUACMECertDisplayName -Cert $Cert
                Write-Host ''
                Write-Host "  Force renew '$displayName' with a brand-new private key?" -ForegroundColor Yellow
                Write-Host '  Use this after a key leak — the next renewal will generate' -ForegroundColor DarkGray
                Write-Host '  a fresh private key instead of reusing the existing one.' -ForegroundColor DarkGray
                Write-Host ''
                if (Confirm-YesNo '  Confirm force renew? (y/N)' -Default $false) {
                    try {
                        _Switch-PAContext -Cert $Cert
                        _Invoke-TUACMEForceRenew -Cert $Cert -DisplayName $displayName
                        Write-Host '  Force renewal completed with new private key.' -ForegroundColor Green
                        Write-EventLogEntry -EventId 1005 -EntryType Information `
                            -Message "TU-ACME: Force-renewed $displayName with new key ($($Cert.ServerName))"
                    } catch {
                        Write-Host "  Error: $_" -ForegroundColor Red
                    }
                    Wait-AnyKey
                }
                return
            }
            '^[Vv]$' {
                $displayName = _Get-TUACMECertDisplayName -Cert $Cert
                Write-Host ''
                Write-Host "  Revoke certificate '$displayName' at the ACME server?" -ForegroundColor Yellow
                Write-Host '  Sends a revocation request to the issuing CA. The local files' -ForegroundColor DarkGray
                Write-Host '  remain — use [D] Delete separately if you also want to purge.' -ForegroundColor DarkGray
                Write-Host '  Use this when the private key has leaked or the cert is no' -ForegroundColor Yellow
                Write-Host '  longer trusted. Revocation cannot be undone.' -ForegroundColor Yellow
                Write-Host ''
                if (Confirm-YesNo '  Confirm revoke? (y/N)' -Default $false) {
                    try {
                        _Switch-PAContext -Cert $Cert
                        _Invoke-TUACMERevoke -Cert $Cert -DisplayName $displayName
                        Write-Host '  Certificate revoked at the ACME server.' -ForegroundColor Green
                        Write-EventLogEntry -EventId 1004 -EntryType Information `
                            -Message "TU-ACME: Revoked certificate $displayName ($($Cert.ServerName))"
                    } catch {
                        Write-Host "  Error: $_" -ForegroundColor Red
                    }
                    Wait-AnyKey
                }
                return
            }
            '^[Dd]$' {
                $displayName = _Get-TUACMECertDisplayName -Cert $Cert
                Write-Host ''
                Write-Host "  Delete certificate for '$displayName' from the Posh-ACME store?" -ForegroundColor Yellow
                Write-Host '  This removes the local certificate, key, and renewal config.' -ForegroundColor DarkGray
                Write-Host '  The ACME order itself is unaffected; the cert is not revoked.' -ForegroundColor DarkGray
                Write-Host ''
                if (Confirm-YesNo '  Confirm delete? (y/N)' -Default $false) {
                    try {
                        _Remove-TUACMECertDir -Cert $Cert
                        Write-Host '  Certificate removed.' -ForegroundColor Green
                        Write-EventLogEntry -EventId 1003 -EntryType Information `
                            -Message "TU-ACME: Removed certificate $displayName ($($Cert.ServerName))"
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

function _Switch-PAContext {
    param($Cert)

    # Switch the active Posh-ACME server+account so that subsequent
    # calls (Submit-Renewal, etc.) target this cert. The dashboard's
    # outer try/finally restores the entry context when the user
    # exits.
    if ($Cert.ServerName) {
        Set-PAServer $Cert.ServerName -ErrorAction SilentlyContinue
    }
    if ($Cert.AccountID) {
        Set-PAAccount -ID $Cert.AccountID -ErrorAction SilentlyContinue
    }
}

function _Get-TUACMECertDisplayName {
    param($Cert)

    if ($Cert.MainDomain) {
        return $Cert.MainDomain
    }
    if ($Cert.CertFile) {
        return Split-Path -Leaf (Split-Path -Parent $Cert.CertFile)
    }
    return '(unknown)'
}

function _Invoke-TUACMERevoke {
    # Thin wrapper around Posh-ACME's Revoke-PACertificate so the test
    # suite can mock this single TU-ACME-defined function rather than
    # mocking a Posh-ACME cmdlet, which on PS 5.1 + Posh-ACME loaded
    # interacts awkwardly with our logging proxies.
    param($Cert, [string] $DisplayName)

    $rvParams = @{ Force = $true }
    if ($Cert.MainDomain) {
        $rvParams['MainDomain'] = $Cert.MainDomain
    } else {
        # Fall back to the cert folder name when the order.json is
        # missing MainDomain (some internal ACME CAs).
        $rvParams['Name'] = $DisplayName
    }
    Revoke-PACertificate @rvParams
}

function _Invoke-TUACMEForceRenew {
    # Thin wrapper combining Set-PAOrder -NewKey and Submit-Renewal
    # -Force. Same testability rationale as _Invoke-TUACMERevoke.
    param($Cert, [string] $DisplayName)

    $orderParams = @{ NewKey = $true }
    if ($Cert.MainDomain) {
        $orderParams['MainDomain'] = $Cert.MainDomain
    } else {
        $orderParams['Name'] = $DisplayName
    }
    Set-PAOrder @orderParams

    if ($Cert.MainDomain) {
        Submit-Renewal -MainDomain $Cert.MainDomain -Force | Out-Null
    } else {
        Submit-Renewal -Force | Out-Null
    }
}

function _Remove-TUACMECertDir {
    <#
    .SYNOPSIS
        Removes a Posh-ACME certificate by wiping its directory on
        disk. Posh-ACME v4 has no Remove-PACertificate cmdlet (only
        Remove-PAAccount), and Get-PACertificate -List discovers
        certs lazily by scanning the filesystem, so deleting the
        folder is the supported way to drop a cert from the local
        store. The cert at the ACME server is not affected — this
        does not revoke; it only forgets locally.
    #>
    param($Cert)

    if (-not $Cert -or -not $Cert.CertFile) {
        throw 'Certificate has no CertFile path; cannot determine folder to remove.'
    }
    $certDir = Split-Path -Parent $Cert.CertFile
    if (-not $certDir -or -not (Test-Path $certDir)) {
        throw "Certificate folder not found: $certDir"
    }
    # Sanity check: only delete if the folder actually looks like a
    # Posh-ACME cert directory. Refuse otherwise so a malformed cert
    # object can't accidentally point us at, say, the user's home.
    $looksRight = (Test-Path (Join-Path $certDir 'cert.cer')) -or
                  (Test-Path (Join-Path $certDir 'order.json'))
    if (-not $looksRight) {
        throw "Folder $certDir does not look like a Posh-ACME cert directory; refusing to delete."
    }
    Remove-Item -Path $certDir -Recurse -Force -ErrorAction Stop
}
