#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Deploys TU-ACME from the repo to the AllUsers PowerShell module path.

.DESCRIPTION
    Run from the repo root. Removes any prior install, copies the
    current TU-ACME folder to $env:ProgramFiles\WindowsPowerShell\Modules\,
    then prints the installed ModuleVersion.

.EXAMPLE
    .\deploy.ps1
#>

$ErrorActionPreference = 'Stop'

$source = Join-Path $PSScriptRoot 'TU-ACME'
$dest   = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules\TU-ACME'

if (-not (Test-Path (Join-Path $source 'TU-ACME.psd1'))) {
    throw "TU-ACME.psd1 not found under '$source'. Run deploy.ps1 from the repo root."
}

if (-not (Get-Module -ListAvailable -Name 'Posh-ACME')) {
    Write-Host 'Warning: Posh-ACME is not installed. Install with:' -ForegroundColor Yellow
    Write-Host '  Install-Module -Name Posh-ACME -Scope AllUsers -Force' -ForegroundColor Gray
}

Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
if (Test-Path $dest) {
    Write-Host "Removing existing install at $dest" -ForegroundColor DarkGray
    Remove-Item -Path $dest -Recurse -Force
}

Write-Host "Copying $source -> $dest" -ForegroundColor Cyan
Copy-Item -Path $source -Destination $dest -Recurse -Force

$installed = Get-Module -ListAvailable -Name TU-ACME | Select-Object -First 1
if (-not $installed) {
    throw 'Deploy completed but Get-Module cannot find TU-ACME. Check $env:PSModulePath.'
}

Write-Host ''
Write-Host "Deployed TU-ACME v$($installed.Version)" -ForegroundColor Green
Write-Host "Start with: Start-TUACME" -ForegroundColor Gray
