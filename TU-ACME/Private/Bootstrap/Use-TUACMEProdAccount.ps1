function Use-TUACMEProdAccount {
    <#
    .SYNOPSIS
        Switches Posh-ACME to the prod directory URL and prod account.
        Called at the top of every prod-facing TUI flow.
    #>
    [CmdletBinding()]
    param()

    $cfg = Get-TUACMEConfig
    if (-not $cfg.Acme.Initialized) {
        throw 'TU-ACME is not initialized. Run Initialize-TUACMEEnvironment first.'
    }
    Set-PAServer -DirectoryUrl $cfg.Acme.ProdDirectoryUrl
    Set-PAAccount -ID $cfg.Acme.ProdAccountId
}
