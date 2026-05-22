function Get-TUACMEAllCertificates {
    <#
    .SYNOPSIS
        Enumerates certificates across every known Posh-ACME server,
        not just the currently active one. Each cert is returned with
        added ServerName / ServerLocation / AccountID properties so
        downstream code (the dashboard) can show provenance and switch
        back to the right server before renewing or deleting.

    .NOTES
        Posh-ACME is globally stateful (one active server + account at
        a time). This helper saves the active context, iterates every
        server/account/cert tuple, and restores the original context
        before returning. Per-iteration failures (e.g. a server with
        no valid account) are skipped instead of aborting the loop.
    #>
    [CmdletBinding()]
    param()

    $origServer  = $null
    $origAccount = $null
    try { $origServer  = Get-PAServer  -ErrorAction SilentlyContinue } catch {}
    try { $origAccount = Get-PAAccount -ErrorAction SilentlyContinue } catch {}

    $all     = New-Object System.Collections.ArrayList
    $skipped = 0

    $servers = @()
    try { $servers = @(Get-PAServer -List -ErrorAction SilentlyContinue) } catch {}

    # Fallback: if -List returned nothing (older Posh-ACME, or a fresh
    # install with no saved servers), at least try the currently
    # active one. Better one row than an empty dashboard.
    if ($servers.Count -eq 0 -and $origServer) {
        $servers = @($origServer)
    }

    try { Write-PALog -Cmdlet '[helper]' -BoundArgs @{ Stage='enum-servers'; Count=$servers.Count } } catch {}

    foreach ($srv in $servers) {
        if (-not $srv) { continue }
        $srvName = if ($srv.Name) { $srv.Name } else { $srv.location }
        $srvUrl  = $srv.location
        if (-not $srvUrl) {
            try { Write-PALog -Cmdlet '[helper]' -BoundArgs @{ Stage='skip-server'; Server=$srvName; Reason='no location URL' } } catch {}
            continue
        }
        # Posh-ACME 4.32 validates Set-PAServer -DirectoryUrl strictly:
        # only built-in short names (LE_PROD, LE_STAGE, etc.) or a
        # full https:// URL are accepted. Custom-named servers
        # ("acme", "acme.fragt.root.local") get rejected if we pass
        # their short Name. Always pass the location URL — it works
        # for both built-in and custom servers.
        try {
            Set-PAServer -DirectoryUrl $srvUrl -ErrorAction Stop
        } catch {
            try { Write-PALog -Cmdlet '[helper]' -BoundArgs @{ Stage='skip-server'; Server=$srvName; Url=$srvUrl; Reason="Set-PAServer failed: $($_.Exception.Message)" } } catch {}
            continue
        }

        $accounts = @()
        try { $accounts = @(Get-PAAccount -List -ErrorAction SilentlyContinue) } catch {}

        foreach ($acc in $accounts) {
            if (-not $acc -or -not $acc.id) { continue }
            try {
                Set-PAAccount -ID $acc.id -ErrorAction Stop
            } catch {
                continue
            }

            $certs = @()
            try { $certs = @(Get-PACertificate -List -ErrorAction SilentlyContinue) } catch {}

            try { Write-PALog -Cmdlet '[helper]' -BoundArgs @{ Stage='enum-certs'; Server=$srvName; Account=$acc.id; Count=$certs.Count } } catch {}

            foreach ($c in $certs) {
                if (-not $c) { continue }

                # Skip non-actionable cert objects. Posh-ACME's
                # Get-PACertificate -List sometimes surfaces partial
                # entries (pending orders, half-deleted folders,
                # in-progress New-PACertificate that the parent
                # process abandoned, or orphan current-order.txt
                # pointers that survive a folder delete). The keep-
                # rule is "cert.cer must physically exist on disk" -
                # without it there is no cert to act on, no thumbprint
                # to compare, no usable Days-Left calculation.
                # MainDomain alone is not enough: Posh-ACME will
                # synthesise it from current-order.txt even after the
                # cert folder is gone, which is exactly the dashboard-
                # ghost case the user hit on 2026-05-22.
                $hasFile = $false
                if ($c.CertFile) {
                    try { $hasFile = Test-Path -LiteralPath $c.CertFile } catch {}
                }
                if (-not $hasFile) {
                    $skipped++
                    try {
                        Write-PALog -Cmdlet '[helper]' -BoundArgs @{
                            Stage     = 'skip-no-certfile'
                            Server    = $srvName
                            Account   = $acc.id
                            MainDomain= "$($c.MainDomain)"
                            CertFile  = "$($c.CertFile)"
                            Thumbprint= "$($c.Thumbprint)"
                            NotAfter  = "$($c.NotAfter)"
                        }
                    } catch {}
                    continue
                }

                Add-Member -InputObject $c -NotePropertyName 'ServerName'     -NotePropertyValue $srvName       -Force
                Add-Member -InputObject $c -NotePropertyName 'ServerLocation' -NotePropertyValue $srv.location -Force
                Add-Member -InputObject $c -NotePropertyName 'AccountID'      -NotePropertyValue $acc.id        -Force

                # Backfill display fields from the X.509 file when the
                # Posh-ACME object has them empty. Happens against
                # internal ACME CAs whose order.json is missing the
                # MainDomain / DnsPlugin / Subject metadata, even
                # though the issued cert.cer itself has CN/Issuer/SANs.
                _Enrich-TUACMECertFromFile -Cert $c

                [void] $all.Add($c)
            }
        }
    }

    try { Write-PALog -Cmdlet '[helper]' -BoundArgs @{ Stage='done'; Kept=$all.Count; Skipped=$skipped } } catch {}

    # Restore the active context (best-effort). Always use the
    # location URL for the same reason as above.
    if ($origServer -and $origServer.location) {
        try { Set-PAServer -DirectoryUrl $origServer.location -ErrorAction SilentlyContinue } catch {}
    }
    if ($origAccount -and $origAccount.id) {
        try { Set-PAAccount -ID $origAccount.id -ErrorAction SilentlyContinue } catch {}
    }

    return ,$all.ToArray()
}

function _Enrich-TUACMECertFromFile {
    <#
    .SYNOPSIS
        Backfills MainDomain (from cert CN), Issuer, and SANs from the
        X.509 cert file when Posh-ACME's in-memory object has those
        fields empty. Some internal ACME CAs return enough info for
        the cert to be issued and saved on disk, but order.json ends
        up without MainDomain / DnsPlugin / Subject — yet the cert.cer
        on disk has CN, Issuer and SubjectAlternativeName populated.
    #>
    param($Cert)

    if (-not $Cert -or -not $Cert.CertFile) { return }
    if (-not (Test-Path $Cert.CertFile))    { return }

    # If everything we'd backfill is already populated, no need to read the file.
    $needsCN     = -not $Cert.MainDomain
    $needsIssuer = -not $Cert.Issuer
    $needsSANs   = (-not $Cert.SANs) -or ($Cert.SANs.Count -eq 0)
    if (-not ($needsCN -or $needsIssuer -or $needsSANs)) { return }

    $x509 = $null
    try {
        $x509 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $Cert.CertFile

        if ($needsCN) {
            $cn = ''
            # Subject is a DN like "CN=df-bpxt4s2-ws, O=Acme, C=DK".
            # Pull the CN value, allowing for quoted forms with commas.
            if ($x509.Subject -match 'CN\s*=\s*"([^"]+)"') {
                $cn = $matches[1].Trim()
            } elseif ($x509.Subject -match 'CN\s*=\s*([^,]+)') {
                $cn = $matches[1].Trim()
            }
            # Fall back to the cert folder leaf (Posh-ACME names cert
            # folders after the cert's MainDomain).
            if (-not $cn) {
                $cn = Split-Path -Leaf (Split-Path -Parent $Cert.CertFile)
            }
            Add-Member -InputObject $Cert -NotePropertyName 'MainDomain' -NotePropertyValue $cn -Force
        }

        if ($needsIssuer) {
            Add-Member -InputObject $Cert -NotePropertyName 'Issuer' -NotePropertyValue $x509.Issuer -Force
        }

        if ($needsSANs) {
            $sans = @()
            $sanExt = $x509.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.17' }
            if ($sanExt) {
                # .Format($false) returns a comma-separated list like
                #   "DNS Name=foo, DNS Name=bar, IP Address=1.2.3.4"
                # We strip the "<type> Name=" / "<type>=" prefix.
                $sans = ($sanExt.Format($false) -split ',') |
                    ForEach-Object { ($_ -replace '^[^=]*=\s*', '').Trim() } |
                    Where-Object { $_ }
            }
            Add-Member -InputObject $Cert -NotePropertyName 'SANs' -NotePropertyValue $sans -Force
        }
    } catch {
        # Silent — enrichment is best-effort; missing fields will just
        # stay empty in the dashboard.
    } finally {
        if ($x509) { try { $x509.Dispose() } catch {} }
    }
}
