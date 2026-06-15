function Invoke-TUACMERenewalSweep {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [int]$ThresholdDays = 30
    )

    $renewed = @()
    $failed = @()

    # Get-TUACMECertificate ensures prod context (UC-7.02). The flat
    # expiry threshold is mandated by UC-7.02 (renew within 30 days);
    # Submit-Renewal then runs with -Force because the sweep already
    # decided. Keep ThresholdDays below the CA's certificate lifetime or
    # every cert is permanently "due".
    $certificates = @(Get-TUACMECertificate)
    $cutoff = (Get-Date).AddDays($ThresholdDays)

    foreach ($certificate in $certificates) {
        if ($null -eq $certificate.NotAfter -or $certificate.NotAfter -ge $cutoff) {
            continue
        }

        $domain = [string]$certificate.MainDomain
        if ([string]::IsNullOrEmpty($domain)) {
            # Submit-Renewal addresses orders by MainDomain; an order with
            # no domain at all cannot be renewed unattended.
            Write-Verbose ('Skipping a certificate with no resolvable domain (thumbprint {0}).' -f $certificate.Thumbprint)
            continue
        }
        try {
            $renewed += Invoke-TUACMERenewCertificate -Domain $domain
        }
        catch {
            # Event 3003 was already written by Invoke-TUACMERenewCertificate;
            # the sweep logs nothing extra and continues to the next cert.
            $failed += [pscustomobject]@{
                Domain = $domain
                Error  = $_.Exception.Message
            }
        }
    }

    return [pscustomobject]@{
        Renewed = $renewed
        Failed  = $failed
    }
}
