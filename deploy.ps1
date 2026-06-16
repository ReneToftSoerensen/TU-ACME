<#
.SYNOPSIS
Dev helper to remove and (re)install the TU-ACME module for local testing.

.DESCRIPTION
Speeds up the test loop: removes TU-ACME from the current session (so its
files are not locked), deletes any previously deployed copy from the
user-scope PowerShell module path, then copies this repo's module into that
path and imports it fresh so `Import-Module TU-ACME` resolves by name.

Use -Uninstall to only remove (session + deployed copy). Use -NoImport to
reinstall without importing. Works on Windows PowerShell 5.1 and PowerShell
7+ (and degrades gracefully on non-Windows PowerShell 7 for load testing).

This is a development convenience and is not part of the shipped module.

.EXAMPLE
.\deploy.ps1
Remove any existing copy, reinstall from source, and import for testing.

.EXAMPLE
.\deploy.ps1 -Uninstall
Remove TU-ACME from the session and the user module path.

.EXAMPLE
.\deploy.ps1 -NoImport
Reinstall the files but do not import the module.
#>
[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$NoImport
)

$ErrorActionPreference = 'Stop'

$moduleName = 'TU-ACME'
$sourceModuleDir = Join-Path $PSScriptRoot $moduleName
$manifestPath = Join-Path $sourceModuleDir ('{0}.psd1' -f $moduleName)

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw ('Module manifest not found at ''{0}''. Run deploy.ps1 from the repo root.' -f $manifestPath)
}

# Resolve the user-scope module path for the running edition. PS 5.1 (Desktop)
# uses WindowsPowerShell; PS 7+ (Core) uses PowerShell; non-Windows PS 7 uses
# the XDG-style profile path. $IsWindows is $null on 5.1, which is always
# Windows, so the Desktop branch handles it.
if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) {
    $userModuleRoot = Join-Path $HOME '.local/share/powershell/Modules'
}
elseif ($PSVersionTable.PSEdition -eq 'Core') {
    $userModuleRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules'
}
else {
    $userModuleRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Modules'
}
$targetModuleDir = Join-Path $userModuleRoot $moduleName

# 1. Unload from the current session so the deployed files are not locked.
if (Get-Module -Name $moduleName) {
    Remove-Module -Name $moduleName -Force
    Write-Host ('Removed ''{0}'' from the current session.' -f $moduleName)
}

# 2. Delete any previously deployed copy.
if (Test-Path -LiteralPath $targetModuleDir) {
    Remove-Item -LiteralPath $targetModuleDir -Recurse -Force
    Write-Host ('Removed deployed copy at ''{0}''.' -f $targetModuleDir)
}

if ($Uninstall) {
    Write-Host 'Uninstall complete.'
    return
}

# 3. Install: copy the module folder into the user module path.
$null = New-Item -ItemType Directory -Path $userModuleRoot -Force
Copy-Item -LiteralPath $sourceModuleDir -Destination $targetModuleDir -Recurse -Force
Write-Host ('Installed ''{0}'' to ''{1}''.' -f $moduleName, $targetModuleDir)

# 4. Import fresh for testing.
if ($NoImport) {
    Write-Host 'Install complete (import skipped).'
    return
}

Import-Module $moduleName -Force
$imported = Get-Module -Name $moduleName
Write-Host ('Imported ''{0}'' version {1}. Run Start-TUACME to test.' -f $moduleName, $imported.Version)
