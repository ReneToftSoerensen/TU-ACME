# Shared bootstrap for all TU-ACME test files.
# Dot-source this at the top of every Describe block's BeforeAll.

$script:ModuleRoot = (Resolve-Path "$PSScriptRoot\..\TU-ACME").Path
$script:ModulePsd1 = Join-Path $script:ModuleRoot 'TU-ACME.psd1'

function global:Import-TUACMEModule {
    $bootstrapFile = $MyInvocation.MyCommand.ScriptBlock.File
    $repoRoot = Split-Path -Parent (Split-Path -Parent $bootstrapFile)
    $psd1 = Join-Path $repoRoot 'TU-ACME\TU-ACME.psd1'
    Remove-Module TU-ACME -ErrorAction SilentlyContinue -Force
    Import-Module $psd1 -Force -ErrorAction Stop
}

function global:Remove-TUACMEModule {
    Remove-Module TU-ACME -ErrorAction SilentlyContinue -Force
}

function global:New-TempTestDir {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) "TUACME-Test-$([System.Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function global:Remove-TempTestDir {
    param([string] $Path)
    if ($Path -and (Test-Path $Path)) {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function global:New-TempConfigEnv {
    $tmp = New-TempTestDir
    $env:_TUACME_TEST_PROGRAMDATA = Join-Path $tmp 'ProgramData'
    $env:_TUACME_TEST_LOCALAPPDATA = Join-Path $tmp 'LocalAppData'
    New-Item -ItemType Directory -Path $env:_TUACME_TEST_PROGRAMDATA -Force | Out-Null
    New-Item -ItemType Directory -Path $env:_TUACME_TEST_LOCALAPPDATA -Force | Out-Null
    return $tmp
}

# Helper: build a ConsoleKeyInfo object (PS 5.1 compatible)
function global:New-FakeKey {
    param(
        [System.ConsoleKey] $Key = [System.ConsoleKey]::Enter,
        [char]              $Char = [char]0
    )
    return New-Object System.ConsoleKeyInfo($Char, $Key, $false, $false, $false)
}

function global:New-FakeCharKey {
    param([char] $Char)
    $key = switch ($Char) {
        'Q' { [System.ConsoleKey]::Q } 'q' { [System.ConsoleKey]::Q }
        default { [System.ConsoleKey]::A }
    }
    return New-Object System.ConsoleKeyInfo($Char, $key, $false, $false, $false)
}

# Posh-ACME stubs — allow Pester to mock these commands when Posh-ACME is not installed.
function global:Get-PAAccount     { param([switch]$List) }
function global:New-PAAccount     { param([switch]$AcceptTOS, [string]$Contact, [string]$KeyLength) }
function global:Set-PAAccount     { param([string]$ID) }
function global:Get-PACertificate { param([switch]$List) }
function global:New-PACertificate { param([string[]]$Domain, [string]$Plugin, $PluginArgs, [switch]$Force) }
function global:Get-PAServer      { param([string]$DirectoryUrl) }
function global:Set-PAServer      { param([string]$DirectoryUrl) }
function global:Set-PAConfig      { param([string]$PostScript, [string]$Server) }
function global:Get-PAPlugin      { param([string]$Name) }
function global:Get-PAPluginArgs  { param([string]$Domain) }
function global:Submit-Renewal    { param([string]$MainDomain, [switch]$AllAccounts, [switch]$Force) }

# IIS cmdlet stubs — allow mocking when WebAdministration is not loaded.
function global:Get-WebBinding        { param([string]$Protocol) }
function global:Set-WebBinding        { param([string]$Name, [string]$PropertyName, [string]$Value) }
function global:Import-PfxCertificate { param([string]$FilePath, [string]$CertStoreLocation, [switch]$Exportable) }

# ScheduledTask cmdlet stubs — allow mocking when ScheduledTasks module is not loaded.
function global:Get-ScheduledTask          { param([string]$TaskName) }
function global:Register-ScheduledTask     { param([string]$TaskName, $Action, $Trigger, $Settings, $Principal, [string]$User, [string]$RunLevel) }
function global:Unregister-ScheduledTask   { param([string]$TaskName, [switch]$Confirm) }
function global:New-ScheduledTaskAction    { param([string]$Execute, [string]$Argument) }
function global:New-ScheduledTaskTrigger   { param([switch]$Daily, [string]$At) }
function global:New-ScheduledTaskSettingsSet { param($ExecutionTimeLimit, [switch]$StartWhenAvailable) }
function global:New-ScheduledTaskPrincipal { param([string]$UserId, [string]$RunLevel) }

