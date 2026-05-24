# Bootstrap.ps1 -- dot-source for TU-ACME Pester unit tests.
# Loads the module from the worktree and ensures a writable ProgramData path
# exists for tests that touch the on-disk config.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here       = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Resolve-Path (Join-Path $here '..\TU-ACME')
$manifest   = Join-Path $moduleRoot 'TU-ACME.psd1'

if (-not $env:ProgramData) {
    # Cross-platform fallback so tests can run under PS 7 on Linux CI runners
    # that still drive the module against a Windows-shaped layout.
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-Test-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $env:ProgramData = $tmp
}

Get-Module TU-ACME | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module $manifest -Force
