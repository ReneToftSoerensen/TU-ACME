<#
.SYNOPSIS
Background certificate renewal for the TU-ACME scheduled task (UC-7.02).

.DESCRIPTION
Renews every certificate in the prod store within the expiry threshold and
imports the results to LocalMachine\My. Designed to run unattended as
SYSTEM: no prompts, no console output; all reporting goes to the Windows
Event Log (ID 1001 per renewal, 3003 per failed cert, 3001 on fatal abort).
#>
[CmdletBinding()]
param(
    [int]$ThresholdDays = 30
)

$ErrorActionPreference = 'Stop'

try {
    if ($null -eq (Get-Module -Name 'TU-ACME')) {
        # The module root is the parent of Scripts\. Initialization warnings
        # are silenced: a scheduled task has no console to read them on.
        $manifestPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'TU-ACME.psd1'
        Import-Module $manifestPath -WarningAction SilentlyContinue 3>$null
    }

    # The sweep is module-private by design (small public surface); this
    # script is part of the module and reaches it via the module scope.
    $module = Get-Module -Name 'TU-ACME'
    $null = & $module { param($Days) Invoke-TUACMERenewalSweep -ThresholdDays $Days } $ThresholdDays
}
catch {
    $message = ('Background renewal job aborted: {0}' -f $_.Exception.Message)
    $module = Get-Module -Name 'TU-ACME'
    if ($null -ne $module) {
        & $module { param($Message) Write-TUACMEEventLog -EventId 3001 -EntryType Error -Message $Message } $message
    }
}
