function Invoke-TUACMERevokeCertificate {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Domain
    )

    # Revocation is a prod-only operation (UC-6.02); the menu owns the
    # confirmation prompt so this function can be reused unattended.
    $null = Use-TUACMEProdAccount

    try {
        $thumbprint = ''
        $certificate = Get-PACertificate -MainDomain $Domain
        if ($null -ne $certificate) {
            $thumbprint = [string]$certificate.Thumbprint
        }

        Revoke-PACertificate -MainDomain $Domain -Force -ErrorAction Stop

        Write-TUACMEEventLog -EventId 1004 -EntryType Information -Message ('Certificate for {0} revoked (thumbprint {1}).' -f $Domain, $thumbprint)

        # Surface any IIS binding still serving the revoked cert so the operator
        # can re-point it (UC-6.02); we report rather than silently unbind.
        $affected = @()
        if (-not [string]::IsNullOrEmpty($thumbprint)) {
            try {
                $affected = @(Get-TUACMEIISBinding | Where-Object { $_.Thumbprint -eq $thumbprint })
            }
            catch {
                $affected = @()
            }
        }

        return [pscustomobject]@{
            Domain           = $Domain
            Thumbprint       = $thumbprint
            AffectedBindings = @($affected)
        }
    }
    catch {
        Write-TUACMEEventLog -EventId 3004 -EntryType Error -Message ('Certificate revocation for {0} failed: {1}' -f $Domain, $_.Exception.Message)
        throw
    }
}
