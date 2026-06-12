function Invoke-TUACMERenewCertificate {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Domain
    )

    $null = Use-TUACMEProdAccount

    try {
        $oldThumbprint = ''
        $oldCertificate = Get-PACertificate -MainDomain $Domain
        if ($null -ne $oldCertificate) {
            $oldThumbprint = [string]$oldCertificate.Thumbprint
        }

        # Both callers (manual menu and the renewal sweep) have already
        # decided the cert must renew, so Posh-ACME's own renewal-window
        # check is bypassed with -Force.
        $newCertificate = Submit-Renewal -MainDomain $Domain -Force -ErrorAction Stop
        if ($null -eq $newCertificate) {
            throw ('Submit-Renewal returned no certificate for {0}.' -f $Domain)
        }

        $newThumbprint = Import-TUACMECertificate -Certificate $newCertificate

        Write-TUACMEEventLog -EventId 1001 -EntryType Information -Message ('Certificate for {0} renewed (old thumbprint {1}, new thumbprint {2}).' -f $Domain, $oldThumbprint, $newThumbprint)

        return [pscustomobject]@{
            Domain        = $Domain
            OldThumbprint = $oldThumbprint
            NewThumbprint = $newThumbprint
            NotAfter      = $newCertificate.NotAfter
        }
    }
    catch {
        Write-TUACMEEventLog -EventId 3003 -EntryType Error -Message ('Certificate renewal for {0} failed: {1}' -f $Domain, $_.Exception.Message)
        throw
    }
}
