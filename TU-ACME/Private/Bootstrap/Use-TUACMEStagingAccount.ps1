function Use-TUACMEStagingAccount {
    <#
    .SYNOPSIS
        Switches Posh-ACME to the staging directory URL and staging account.
        Only caller: the Dry-run order flow.
    .DESCRIPTION
        Reads config.json, validates Acme.Initialized, then calls
        Set-PAServer -DirectoryUrl <staging> and Set-PAAccount -ID <stagingId>.
        Throws if config is missing or not initialized.
    #>
    [CmdletBinding()]
    param()

    $cfg = Get-TUACMEConfig
    if (-not $cfg.Acme -or -not $cfg.Acme.Initialized) {
        throw 'TU-ACME is not initialized. Run Initialize-TUACMEEnvironment first.'
    }
    if ([string]::IsNullOrWhiteSpace($cfg.Acme.StagingDirectoryUrl) -or
        [string]::IsNullOrWhiteSpace($cfg.Acme.StagingAccountId)) {
        throw 'TU-ACME staging configuration is incomplete (missing URL or account ID).'
    }

    Set-PAServer -DirectoryUrl $cfg.Acme.StagingDirectoryUrl
    Set-PAAccount -ID $cfg.Acme.StagingAccountId
}
