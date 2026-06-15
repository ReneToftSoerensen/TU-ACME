function Invoke-TUACMERenewCertificate {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Domain,

        # Rotate the private key on renewal (force-renew, UC-6.03). Logs under
        # event 1005 instead of 1001; the superseded cert stays in the store.
        [switch]$NewKey
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
        $renewParams = @{
            MainDomain  = $Domain
            Force       = $true
            ErrorAction = 'Stop'
        }
        if ($NewKey) {
            $renewParams['NewKey'] = $true
        }
        $newCertificate = Submit-Renewal @renewParams
        if ($null -eq $newCertificate) {
            throw ('Submit-Renewal returned no certificate for {0}.' -f $Domain)
        }

        $newThumbprint = Import-TUACMECertificate -Certificate $newCertificate

        if ($NewKey) {
            Write-TUACMEEventLog -EventId 1005 -EntryType Information -Message ('Certificate for {0} force-renewed with a new key (old thumbprint {1}, new thumbprint {2}).' -f $Domain, $oldThumbprint, $newThumbprint)
        }
        else {
            Write-TUACMEEventLog -EventId 1001 -EntryType Information -Message ('Certificate for {0} renewed (old thumbprint {1}, new thumbprint {2}).' -f $Domain, $oldThumbprint, $newThumbprint)
        }

        # Best-effort IIS rebind + old-cert cleanup. A renewal that issued a
        # fresh cert is never rolled back by a binding or cleanup failure
        # (UC-9.02, UC-9.03); failures are logged (event 2001) and skipped.
        # Non-IIS hosts and certs with no matching binding are a no-op.
        $rebindUpdated = 0
        $rebindFailed = 0
        try {
            $rebind = Update-TUACMEIISBinding -OldThumbprint $oldThumbprint -NewThumbprint $newThumbprint -Certificate $newCertificate
            $rebindUpdated = @($rebind.Updated).Count
            $rebindFailed = @($rebind.Failed).Count
            # Only delete the superseded cert once *every* targeted binding moved
            # to the new thumbprint. A binding left on the old thumbprint would
            # break if the old cert were deleted, so a partial rebind keeps it
            # (the next sweep retries cleanup) (UC-9.03).
            if ($rebindUpdated -gt 0 -and $rebindFailed -eq 0 -and -not [string]::IsNullOrEmpty($oldThumbprint) -and $oldThumbprint -ne $newThumbprint) {
                $null = Remove-TUACMEWebHostingCertificate -Thumbprint $oldThumbprint
            }
        }
        catch {
            Write-TUACMEEventLog -EventId 2001 -EntryType Warning -Message ('IIS rebind after renewing {0} failed: {1}' -f $Domain, $_.Exception.Message)
        }

        return [pscustomobject]@{
            Domain        = $Domain
            OldThumbprint = $oldThumbprint
            NewThumbprint = $newThumbprint
            NotAfter      = $newCertificate.NotAfter
            RebindUpdated = $rebindUpdated
            RebindFailed  = $rebindFailed
        }
    }
    catch {
        $errorId = 3003
        $operation = 'renewal'
        if ($NewKey) {
            $errorId = 3005
            $operation = 'force-renew with new key'
        }
        Write-TUACMEEventLog -EventId $errorId -EntryType Error -Message ('Certificate {0} for {1} failed: {2}' -f $operation, $Domain, $_.Exception.Message)
        throw
    }
}
