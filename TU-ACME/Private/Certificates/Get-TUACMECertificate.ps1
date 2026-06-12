function Get-TUACMECertificate {
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    # Dashboard and renewal flows read the prod store only; staging certs are
    # throwaway dry-run artifacts (UC-3.01).
    $null = Use-TUACMEProdAccount

    # Get-PACertificate -List surfaces phantom entries for abandoned or
    # pending orders with every field null; keep only entries that name a
    # domain or have an issued cert file on disk.
    $certificates = @(Get-PACertificate -List | Where-Object {
            (-not [string]::IsNullOrEmpty([string]$_.MainDomain)) -or
            ((-not [string]::IsNullOrEmpty([string]$_.CertFile)) -and (Test-Path -LiteralPath ([string]$_.CertFile)))
        })

    # Internal CAs can issue successfully while leaving MainDomain empty in
    # the Posh-ACME order; backfill from the X.509 subject CN, falling back
    # to the cert's store folder name.
    foreach ($certificate in $certificates) {
        if (-not [string]::IsNullOrEmpty([string]$certificate.MainDomain)) {
            continue
        }

        $domain = ''
        $certFile = [string]$certificate.CertFile
        if (-not [string]::IsNullOrEmpty($certFile)) {
            $domain = Get-TUACMECertificateSubjectCN -Path $certFile
            if ([string]::IsNullOrEmpty($domain)) {
                $domain = Split-Path -Path (Split-Path -Path $certFile -Parent) -Leaf
            }
        }

        $certificate | Add-Member -MemberType NoteProperty -Name 'MainDomain' -Value $domain -Force
    }

    return $certificates
}
