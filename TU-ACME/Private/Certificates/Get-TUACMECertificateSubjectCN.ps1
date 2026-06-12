function Get-TUACMECertificateSubjectCN {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($Path)
        if ($certificate.Subject -match 'CN=([^,]+)') {
            return $Matches[1].Trim()
        }
    }
    catch {
        Write-Verbose ('Could not read certificate subject from ''{0}'': {1}' -f $Path, $_.Exception.Message)
    }

    return ''
}
