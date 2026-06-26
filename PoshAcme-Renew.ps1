<#
.SYNOPSIS
    Headless renewal runner for TU-ACME. Invoked by the Windows Scheduled Task
    registered via the T menu in Start-TUACME.

.DESCRIPTION
    1. Sets POSHACME_HOME to the shared TU-ACME store.
    2. Imports the TU-ACME module.
    3. Activates the ACME server / account supplied via -ServerName / -AccountID
       (or uses the currently active context if neither is supplied).
    4. Calls Invoke-RenewAll [-Force] which handles renewal, cert install, IIS
       rebinding, post-deploy hook, and logging — identical to the interactive path.

    Exit codes:
        0 = success (including nothing-due)
        1 = one or more renewals / rebinds failed (partial)
        2 = fatal setup error (module unavailable, server / account error, etc.)

.PARAMETER ServerName
    Optional ACME server name (alias or directory URL). Omit to use the
    currently active server.

.PARAMETER AccountID
    Optional Posh-ACME account ID to activate before renewal. Omit to use the
    currently active account.

.PARAMETER Force
    Renew all orders regardless of Posh-ACME's RenewAfter / ARI schedule.

.PARAMETER CertStore
    LocalMachine certificate store to import renewed certs into.
    Overrides the value stored in config.json.

.PARAMETER PostDeployHook
    Path to an optional .ps1 post-deploy hook. Overrides config.json.
    Set to an empty string to disable the hook for this run.

.PARAMETER LogPath
    Log file path. Defaults to %ProgramData%\TU-ACME\renewal.log.

.PARAMETER WhatIf
    Simulate actions without making any changes.

.EXAMPLE
    pwsh -NoProfile -ExecutionPolicy Bypass -File .\PoshAcme-Renew.ps1
    pwsh -NoProfile -ExecutionPolicy Bypass -File .\PoshAcme-Renew.ps1 -Force
    pwsh -NoProfile -ExecutionPolicy Bypass -File .\PoshAcme-Renew.ps1 -ServerName LE_PROD -AccountID abc123
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator
#Requires -Modules Posh-ACME, IISAdministration

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ServerName    = '',
    [string]$AccountID     = '',
    [switch]$Force,
    [string]$CertStore     = '',
    [string]$PostDeployHook = '',
    [string]$LogPath       = '',
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---- Shared ACME home -------------------------------------------------------
# Mirror what TU-ACME.psm1 computes so SYSTEM and the interactive admin share
# the same Posh-ACME data store.
$sharedACMEHome = Join-Path $env:ProgramData 'TU-ACME' 'ACME'
if (-not (Test-Path $sharedACMEHome)) {
    try { New-Item -ItemType Directory -Path $sharedACMEHome -Force | Out-Null } catch { }
}
$env:POSHACME_HOME = $sharedACMEHome

# ---- Import TU-ACME module --------------------------------------------------
# Try the deployed location first (module sitting next to this script), then
# fall back to the development tree.
$scriptDir     = Split-Path $MyInvocation.MyCommand.Path -Parent
$deployedPsd1  = Join-Path $scriptDir 'src' 'TU-ACME.psd1'
$devPsd1       = Join-Path $scriptDir 'src' 'TU-ACME.psd1'   # same for repo root layout

$modulePsd1 = if (Test-Path $deployedPsd1) { $deployedPsd1 } else { $devPsd1 }
if (-not (Test-Path $modulePsd1)) {
    Write-Error "Cannot find TU-ACME module at: $modulePsd1"
    exit 2
}

try {
    Import-Module $modulePsd1 -Force -ErrorAction Stop
} catch {
    Write-Error "Failed to import TU-ACME module: $_"
    exit 2
}

# ---- Runner error logging helper --------------------------------------------
# Write-TUACMELog is a private module function; invoke it in the module scope so
# unattended failures land in the shared renewal log, not just stderr. Falls back
# to stderr only if the module call itself fails.
function Write-RunnerErrorLog {
    param([Parameter(Mandatory)][string]$Message)
    try {
        Invoke-Command -ScriptBlock {
            param($m) Write-TUACMELog -Level ERROR -Message $m
        } -ArgumentList $Message -ModuleName TU-ACME
    } catch {
        Write-Error "Could not write error to renewal log: $_"
    }
}

# ---- Apply optional overrides to module config ------------------------------
# The module exposes $script:Config via InModuleScope; override through the
# module's exported state by dot-running inside the module scope.
if ($CertStore -or $PostDeployHook -or $LogPath) {
    Invoke-Command -ScriptBlock {
        param($cs, $pdh, $lp)
        if ($cs)  { $script:Config['CertStore']      = $cs  }
        if ($pdh -ne $null) { $script:Config['PostDeployHook'] = $pdh }
        if ($lp)  { $script:LogPath = $lp }
    } -ArgumentList $CertStore, $PostDeployHook, $LogPath `
      -ModuleName TU-ACME
}

# ---- Set Dry-Run / What-If flags in module scope ----------------------------
if ($WhatIf) {
    Invoke-Command -ScriptBlock { $script:WhatIf = $true } -ModuleName TU-ACME
}

# ---- Activate server / account if supplied ----------------------------------
$exitCode = 0

if ($ServerName) {
    try {
        $srvArg = Invoke-Command -ScriptBlock {
            param($s) Resolve-PAServerArg -ServerInput $s
        } -ArgumentList $ServerName -ModuleName TU-ACME

        Set-PAServer $srvArg -ErrorAction Stop | Out-Null
    } catch {
        Write-Error "Cannot activate server '$ServerName': $_"
        Write-RunnerErrorLog "Cannot activate server '$ServerName': $_"
        exit 2
    }
}

if ($AccountID) {
    try {
        Set-PAAccount -ID $AccountID -ErrorAction Stop | Out-Null
    } catch {
        Write-Error "Cannot activate account '$AccountID': $_"
        Write-RunnerErrorLog "Cannot activate account '$AccountID': $_"
        exit 2
    }
}

# ---- Run renewal ------------------------------------------------------------
try {
    # Invoke-RenewAll is a private function; call it via Invoke-Command in the
    # module scope so it has access to all private helpers and module-level state.
    Invoke-Command -ScriptBlock {
        param([bool]$f)
        Invoke-RenewAll -Force:$f
    } -ArgumentList ([bool]$Force) -ModuleName TU-ACME
} catch {
    Write-Error "Renewal run failed: $_"
    Write-RunnerErrorLog "Renewal run failed: $_"
    $exitCode = 1
}

exit $exitCode
