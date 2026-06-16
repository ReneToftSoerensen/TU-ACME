function Get-TUACMEIISProvider {
    <#
    .SYNOPSIS
    Selects the IIS PowerShell provider usable in this session (issue #16).

    .DESCRIPTION
    TU-ACME targets both Windows PowerShell 5.1 and PowerShell 7. The classic
    WebAdministration module loads natively on 5.1 but is unreliable under
    PowerShell 7 (Core), where the newer IISAdministration module is the
    supported path. Returns the provider to use ('IISAdministration' or
    'WebAdministration'), preferring the edition-native module and falling back
    to whichever is actually present, or $null when neither is available.

    Returning $null lets callers distinguish "IIS management is unavailable in
    this session" from "IIS has no bindings", instead of both surfacing as an
    empty list (issue #16).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $hasIISAdministration = $null -ne (Get-Command -Name 'Get-IISSite' -ErrorAction SilentlyContinue)
    $hasWebAdministration = $null -ne (Get-Command -Name 'Get-WebBinding' -ErrorAction SilentlyContinue)

    # Neither cmdlet is loaded yet: import whichever module is installed so a
    # fresh session still discovers IIS. Importing is best-effort.
    if (-not $hasIISAdministration -and -not $hasWebAdministration) {
        foreach ($moduleName in @('IISAdministration', 'WebAdministration')) {
            if (Get-Module -ListAvailable -Name $moduleName -ErrorAction SilentlyContinue) {
                try {
                    Import-Module -Name $moduleName -ErrorAction Stop
                }
                catch {
                    # A module that fails to import is treated as unavailable.
                }
            }
        }
        $hasIISAdministration = $null -ne (Get-Command -Name 'Get-IISSite' -ErrorAction SilentlyContinue)
        $hasWebAdministration = $null -ne (Get-Command -Name 'Get-WebBinding' -ErrorAction SilentlyContinue)
    }

    # Prefer IISAdministration on PowerShell 7 (Core) and WebAdministration on
    # Windows PowerShell 5.1; fall back to whichever is present on the host.
    if (Test-TUACMEIsCoreEdition) {
        if ($hasIISAdministration) {
            return 'IISAdministration'
        }
        if ($hasWebAdministration) {
            return 'WebAdministration'
        }
    }
    else {
        if ($hasWebAdministration) {
            return 'WebAdministration'
        }
        if ($hasIISAdministration) {
            return 'IISAdministration'
        }
    }

    return $null
}
