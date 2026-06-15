function Test-TUACMEIsAdministrator {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Test-TUACMEIsWindows)) {
        return $false
    }

    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}
