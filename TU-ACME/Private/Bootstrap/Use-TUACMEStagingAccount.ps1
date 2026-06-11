function Use-TUACMEStagingAccount {
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

    Set-PAServer -DirectoryUrl $config.StagingDirectoryUrl
    if (-not [string]::IsNullOrEmpty([string]$config.StagingAccountId)) {
        Set-PAAccount -ID $config.StagingAccountId
    }

    return $previousUrl
}
