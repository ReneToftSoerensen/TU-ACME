function Get-TUACMECertificate {
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    # Dashboard and renewal flows read the prod store only; staging certs are
    # throwaway dry-run artifacts (UC-3.01).
    $null = Use-TUACMEProdAccount
    return @(Get-PACertificate -List)
}
