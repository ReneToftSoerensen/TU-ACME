function Get-TUACMEUnboundWebHostingCertificate {
    <#
    .SYNOPSIS
    Lists WebHosting certificates not referenced by any IIS binding (UC-9.03).

    .DESCRIPTION
    Returns certificates in Cert:\LocalMachine\WebHosting whose thumbprint is not
    used by any current IIS binding. These are typically old certs left behind
    when a post-renewal cleanup failed; the operator can delete them manually.
    Returns an empty list on non-Windows hosts or when discovery fails.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    if (-not (Test-TUACMEIsWindows)) {
        return @()
    }

    $boundThumbprints = @{}
    try {
        foreach ($binding in @(Get-TUACMEIISBinding)) {
            $thumbprint = [string]$binding.Thumbprint
            if (-not [string]::IsNullOrEmpty($thumbprint)) {
                $boundThumbprints[$thumbprint] = $true
            }
        }
    }
    catch {
        return @()
    }

    try {
        return @(Get-ChildItem -Path 'Cert:\LocalMachine\WebHosting' -ErrorAction Stop |
            Where-Object { -not $boundThumbprints.ContainsKey([string]$_.Thumbprint) })
    }
    catch {
        return @()
    }
}
