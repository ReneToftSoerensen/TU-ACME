function Test-TUACMEIISAvailable {
    <#
    .SYNOPSIS
    Reports whether IIS management is usable in this session (issue #16).

    .DESCRIPTION
    True only on Windows when an IIS PowerShell provider (IISAdministration or
    WebAdministration) is available. Interactive handlers use this to tell the
    operator that IIS management is unavailable — e.g. running under PowerShell
    7 without IISAdministration installed — instead of the misleading
    "No HTTPS bindings found".
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Test-TUACMEIsWindows)) {
        return $false
    }

    return ($null -ne (Get-TUACMEIISProvider))
}
