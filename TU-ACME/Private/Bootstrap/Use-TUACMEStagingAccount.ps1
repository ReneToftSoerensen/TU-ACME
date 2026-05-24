function Use-TUACMEStagingAccount {
    <#
    .SYNOPSIS
        Switches Posh-ACME to the staging directory URL and staging account.
        Only caller: the Dry-run order flow.
    #>
    [CmdletBinding()]
    param()

    $cfg = Get-TUACMEConfig
    if (-not $cfg.Acme.Initialized) {
        throw 'TU-ACME is not initialized. Run Initialize-TUACMEEnvironment first.'
    }
    Set-PAServer -DirectoryUrl $cfg.Acme.StagingDirectoryUrl
    Set-PAAccount -ID $cfg.Acme.StagingAccountId
}
