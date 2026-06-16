function Test-TUACMEIsCoreEdition {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # PowerShell 7 reports 'Core'; Windows PowerShell 5.1 reports 'Desktop'.
    # The classic WebAdministration module is unreliable under Core, so this
    # gates IIS provider selection (issue #16).
    return ($PSVersionTable.PSEdition -eq 'Core')
}
