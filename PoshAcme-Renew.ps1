<#
.SYNOPSIS
    Headless, non-interactive Posh-ACME renewal runner for TU-ACME (ISSUE-02).

.DESCRIPTION
    Renews due Posh-ACME orders, re-installs the renewed certificates into the
    configured store, and re-points the matching IIS HTTPS bindings - all without
    a console. Designed to run under the SYSTEM Windows Scheduled Task registered
    by the TU-ACME interactive UI (the T menu), but can also be run by hand.

    This script is a thin wrapper: it imports the TU-ACME module and calls the
    shared orchestrator Invoke-TUACMERenewal, so unattended and interactive
    renewals reuse the exact same install/rebind helpers (Private/Deploy.ps1).

    By default it renews orders Posh-ACME reports as due (RenewAfter/ARI) and, as
    a safety net, force-renews any certificate within the configured
    RenewalDaysBefore (default 30) days of expiry even if RenewAfter has not yet
    elapsed. Use -Force to renew every order regardless of RenewAfter.

    Exit codes:
        0 = success, including "nothing was due" (no-op is success).
        1 = one or more renewals, rebinds, or post-deploy hooks failed (partial).
        2 = fatal/setup error (module/POSHACME_HOME unavailable, no accounts,
            account not found, or ambiguous account).

.PARAMETER ServerName
    ACME server alias or directory URL; resolved like the TUI. Omit = all servers.

.PARAMETER AccountID
    Restrict to one account. Omit = all accounts on the server(s). When supplied
    without -ServerName, the server is inferred from the single matching account
    (the run aborts with exit 2 if zero or multiple accounts match the ID).

.PARAMETER Force
    Renew regardless of RenewAfter (maps to Submit-Renewal -AllOrders -Force).

.PARAMETER NoCache
    Bypass cached Posh-ACME order state: refresh orders from the server
    (Get-PAOrder -List -Refresh) before deciding what is due, so ARI/RenewAfter
    decisions use current data. Does not force renewal - use -Force for that.

.PARAMETER CertStore
    LocalMachine store name for import + binding. Default: config CertStore.

.PARAMETER PostDeployHook
    Optional .ps1 invoked per renewed cert for non-IIS deploy. Empty = off.

.PARAMETER LogPath
    Log file path. Default: %ProgramData%\TU-ACME\renewal.log (module default).

.PARAMETER WhatIf
    Make no changes; log the intended actions only.

.EXAMPLE
    pwsh -NoProfile -ExecutionPolicy Bypass -File .\PoshAcme-Renew.ps1

.EXAMPLE
    pwsh -NoProfile -ExecutionPolicy Bypass -File .\PoshAcme-Renew.ps1 -ServerName LE_PROD -AccountID abc123
#>

#requires -Version 7.0
#requires -RunAsAdministrator
#requires -Modules Posh-ACME, IISAdministration

[CmdletBinding(SupportsShouldProcess)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '',
    Justification = 'Thin wrapper; -WhatIf is forwarded to Invoke-TUACMERenewal which tracks it for ShouldProcess-aware helpers.')]
param(
    [string]$ServerName,
    [string]$AccountID,
    [switch]$Force,
    [switch]$NoCache,
    [string]$CertStore,
    [string]$PostDeployHook,
    [string]$LogPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Locate the TU-ACME module: a deployed copy sits next to this script; otherwise
# fall back to the repo layout (./src/TU-ACME.psd1).
$candidatePaths = @(
    (Join-Path $PSScriptRoot 'TU-ACME.psd1'),
    (Join-Path $PSScriptRoot 'src' | Join-Path -ChildPath 'TU-ACME.psd1')
)
$modulePath = $candidatePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $modulePath) {
    Write-Error "TU-ACME module not found. Looked in: $($candidatePaths -join ', ')"
    exit 2
}

try {
    Import-Module $modulePath -Force -ErrorAction Stop
} catch {
    Write-Error "Failed to import TU-ACME module from '$modulePath': $_"
    exit 2
}

# Forward only the parameters that were actually supplied so the module's own
# defaults (CertStore, PostDeployHook, LogPath) apply when omitted.
$forward = @{}
foreach ($name in 'ServerName', 'AccountID', 'Force', 'NoCache', 'CertStore', 'PostDeployHook', 'LogPath', 'WhatIf') {
    if ($PSBoundParameters.ContainsKey($name)) { $forward[$name] = $PSBoundParameters[$name] }
}

$exitCode = Invoke-TUACMERenewal @forward
exit $exitCode
