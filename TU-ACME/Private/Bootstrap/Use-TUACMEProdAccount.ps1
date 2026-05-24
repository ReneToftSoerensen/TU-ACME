function Use-TUACMEProdAccount {
    <#
    .SYNOPSIS
        Switches Posh-ACME to the prod directory URL and prod account.
        Called at the top of every prod-facing TUI flow.
    .DESCRIPTION
        Reads config.json, validates Acme.Initialized, then calls
        Set-PAServer -DirectoryUrl <prod> and Set-PAAccount -ID <prodId>.
        Throws if config is missing or not initialized.
    #>
    [CmdletBinding()]
    param()

    $cfg = Get-TUACMEConfig
    if (-not $cfg.Acme -or -not $cfg.Acme.Initialized) {
        throw 'TU-ACME is not initialized. Run Initialize-TUACMEEnvironment first.'
    }
    if ([string]::IsNullOrWhiteSpace($cfg.Acme.ProdDirectoryUrl) -or
        [string]::IsNullOrWhiteSpace($cfg.Acme.ProdAccountId)) {
        throw 'TU-ACME prod configuration is incomplete (missing URL or account ID).'
    }

    Set-PAServer -DirectoryUrl $cfg.Acme.ProdDirectoryUrl
    Set-PAAccount -ID $cfg.Acme.ProdAccountId
}
