function Invoke-TUACMERenewalSweep {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [int]$ThresholdDays = 30
    )

    $renewed = @()
    $failed = @()

    # Get-TUACMECertificate ensures prod context (UC-7.02).
    $certificates = @(Get-TUACMECertificate)
    $cutoff = (Get-Date).AddDays($ThresholdDays)

    foreach ($certificate in $certificates) {
        if ($certificate.NotAfter -ge $cutoff) {
            continue
        }

        $domain = [string]$certificate.MainDomain
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
