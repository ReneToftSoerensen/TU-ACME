# Shared test bootstrap: load the Posh-ACME stubs, then TU-ACME without
# running environment initialization (-ArgumentList $true binds SkipInitialize).
$testsRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $testsRoot

if ([string]::IsNullOrEmpty($env:TUACME_DATA_DIR)) {
    $env:TUACME_DATA_DIR = Join-Path ([System.IO.Path]::GetTempPath()) 'TU-ACME-Tests'
}

Get-Module -Name 'TU-ACME' | Remove-Module -Force

Import-Module (Join-Path (Join-Path $testsRoot 'Fixtures') 'PoshACME.Stubs.psm1') -Global -Force
Import-Module (Join-Path (Join-Path $testsRoot 'Fixtures') 'WindowsCmdlets.Stubs.psm1') -Global -Force
Import-Module (Join-Path (Join-Path $repoRoot 'TU-ACME') 'TU-ACME.psd1') -ArgumentList $true -Force
