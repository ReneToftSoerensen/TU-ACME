function Import-TUACMEPoshACME {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (Get-Module -Name 'Posh-ACME') {
        return $true
    }

    try {
        Import-Module -Name 'Posh-ACME' -Global -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}
