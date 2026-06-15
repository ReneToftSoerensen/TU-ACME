function Use-TUACMEProdAccount {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # Default DPAPI plugin-arg encryption is bound to the ordering user;
        # alt encryption keeps args readable by the SYSTEM renewal task.
        # Exposed here because this is the only Set-PAAccount call site.
        [switch]$UseAltPluginEncryption
    )

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
        if ($UseAltPluginEncryption) {
            Set-PAAccount -ID $config.ProdAccountId -UseAltPluginEncryption
        }
        else {
            Set-PAAccount -ID $config.ProdAccountId
        }
    }

    return $previousUrl
}
