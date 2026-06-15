function Read-TUACMEKey {
    [CmdletBinding()]
    [OutputType([System.ConsoleKeyInfo])]
    param()

    # Console input bottleneck so unit tests can mock keystrokes;
    # $true suppresses echo.
    return [System.Console]::ReadKey($true)
}
