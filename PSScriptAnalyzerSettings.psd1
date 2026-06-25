@{
    # PSScriptAnalyzer settings for TU-ACME.
    #
    # PSUseSingularNouns is excluded because several function names are fixed by the
    # design / integration contract and are intentionally plural:
    #   - Get-AllPAAccounts is referenced by name as a reuse seam in ISSUE-02.
    #   - The WACS-style pickers (Select-IISSitesUI, Select-IISBindingsUI) and
    #     listing helpers (Get-IISSslBindings, Get-PAOrdersList, Get-IISBindingsRaw)
    #     read naturally as plurals and match the approved UX vocabulary.
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        'PSUseSingularNouns',
        # Write-Host is the sanctioned output channel for this TUI (see
        # .github/instructions/powershell.instructions.md "Output").
        'PSAvoidUsingWriteHost',
        # Several catches are deliberate best-effort probes / context restores
        # where a failure is intentionally ignored (e.g. restoring the previously
        # active Posh-ACME server/account, probing optional account properties).
        'PSAvoidUsingEmptyCatchBlock'
    )
}
