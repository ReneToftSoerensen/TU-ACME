function Test-TUACMEIsWindows {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # $IsWindows does not exist on Windows PowerShell 5.1; the OS environment
    # variable is reliable on both editions.
    return ($env:OS -eq 'Windows_NT')
}
