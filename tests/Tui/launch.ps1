<#
    launch.ps1 - Harness used by the tui-test specs to drive the interactive TUI.

    tui-test starts this script in a real pty (pwsh -NoProfile -File launch.ps1).
    It points every TU-ACME state path at a throwaway temp directory (so the
    suite never touches a developer's real %ProgramData%\TU-ACME store), imports
    the module, then launches the interactive menu. Pass -DryRun to exercise the
    Dry-Run banner.

    The module is portable: off Windows the elevation/IIS/ACL prerequisites in
    Bootstrap.ps1 self-skip, so the menu loop is reached without admin or IIS.
#>
[CmdletBinding()]
param(
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Isolate all TU-ACME state under a per-run temp directory. The module derives
# its ProgramData paths from $env:ProgramData at import time, so set it first.
$env:ProgramData = Join-Path ([IO.Path]::GetTempPath()) ("TU-ACME-tuitest-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $env:ProgramData -Force | Out-Null

$modulePath = Join-Path $PSScriptRoot '../../src/TU-ACME.psd1'
Import-Module $modulePath -Force

if ($DryRun) {
    Start-TUACME -DryRun
} else {
    Start-TUACME
}
