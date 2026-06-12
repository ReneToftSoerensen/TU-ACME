function Use-TUACMEProdAccount {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # Account ids are not required so the first-run wizard can switch servers
    # before the accounts exist; New-PAAccount auto-activates the new account.
    $config = Get-TUACMEConfig -RequireAccountIds $false

    $previousUrl = $null
    $server = Get-PAServer
    if ($null -ne $server) {
        $previousUrl = $server.location
    }

    Set-PAServer -DirectoryUrl $config.ProdDirectoryUrl
    if (-not [string]::IsNullOrEmpty([string]$config.ProdAccountId)) {
        Set-PAAccount -ID $config.ProdAccountId
    }

    return $previousUrl
}
