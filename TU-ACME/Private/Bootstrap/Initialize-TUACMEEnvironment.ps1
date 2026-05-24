function Initialize-TUACMEEnvironment {
    <#
    .SYNOPSIS
        First-run wizard: prompts for prod URL, staging URL, contact email;
        creates one Posh-ACME account per environment; persists the IDs to
        config.json. Idempotent unless -Force.
    #>
    [CmdletBinding()]
    param([switch] $Force)

    throw 'Initialize-TUACMEEnvironment not yet implemented (lands in Step 4).'
}
