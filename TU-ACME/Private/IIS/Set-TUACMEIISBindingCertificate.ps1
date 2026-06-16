function Set-TUACMEIISBindingCertificate {
    <#
    .SYNOPSIS
    Points an IIS HTTPS binding at a certificate via IISAdministration (issue #16).

    .DESCRIPTION
    The IISAdministration provider (PowerShell 7) has no Set-WebBinding cmdlet,
    so binding certificate changes go through the Microsoft.Web.Administration
    ServerManager: set certificateHash + certificateStoreName on the matching
    binding(s), then CommitChanges() to persist atomically. Other binding
    settings (port, host header, SNI flags) are left untouched. Throws if the
    site or binding cannot be found so the caller logs and skips it (UC-9.03).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteName,

        [Parameter(Mandatory = $true)]
        [string]$BindingInformation,

        [Parameter(Mandatory = $true)]
        [string]$Thumbprint,

        [string]$StoreName = 'WebHosting'
    )

    $manager = Get-IISServerManager
    $site = $manager.Sites[$SiteName]
    if ($null -eq $site) {
        throw ("IIS site '{0}' was not found." -f $SiteName)
    }

    $hashBytes = Convert-TUACMEThumbprintToByte -Thumbprint $Thumbprint
    $matched = $false
    foreach ($binding in $site.Bindings) {
        # Match the HTTPS binding only: BindingInformation (ip:port:host) is not
        # unique across protocols, and setting certificateHash on a non-SSL
        # binding throws, so a co-located HTTP binding must be skipped.
        if ([string]$binding.BindingInformation -eq $BindingInformation -and [string]$binding.Protocol -eq 'https') {
            $binding.CertificateHash = $hashBytes
            $binding.CertificateStoreName = $StoreName
            $matched = $true
        }
    }

    if (-not $matched) {
        throw ("No HTTPS binding '{0}' was found on IIS site '{1}'." -f $BindingInformation, $SiteName)
    }

    $manager.CommitChanges()
}
