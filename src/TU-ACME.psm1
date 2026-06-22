<#
    TU-ACME root module.

    Dot-sources every Private/* helper and Public/* command, then exports only the
    public entry point (Start-TUACME). Module-scoped state is shared across all
    dot-sourced functions because they load into this module's scope.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------
# Module-scoped state (shared by all Private/Public functions)
# ------------------------------------------------------------

# Dry-Run / What-If flags, toggled by Start-TUACME switches.
$script:DryRun = $false
$script:WhatIf = $false

# System-wide install location. config.json and the shared Posh-ACME data store
# both live here so the interactive admin and the SYSTEM scheduled task see the
# same accounts, servers, orders, and certs. $env:ProgramData is only present on
# Windows; fall back to a temp path so the module still imports (and unit-tests)
# on non-Windows CI runners.
$script:ProgramDataRoot = if ($env:ProgramData) { $env:ProgramData } else { [IO.Path]::GetTempPath() }
$script:ProgramDataDir  = Join-Path $script:ProgramDataRoot 'TU-ACME'
$script:ConfigFile      = Join-Path $script:ProgramDataDir 'config.json'
$script:SharedACMEHome  = Join-Path $script:ProgramDataDir 'ACME'
$script:LogPath         = Join-Path $script:ProgramDataDir 'renewal.log'

# Scheduled-task name prefix; the T menu lists tasks starting with this.
$script:TaskPrefix = 'TU-ACME-'

# Windows Event Log source used by the unattended runner (ISSUE-02).
$script:EventLogSource = 'TU-ACME'

# Default configuration. Persisted to $script:ConfigFile on first save.
# (Key type/length are read from the active account, not stored here.)
$script:Config = [ordered]@{
    ACMEServer        = 'acme.fragt.root.local'  # alias or directory URL
    ContactEmail      = ''
    ValidationPlugin  = 'WebSelfHost'            # WebSelfHost (HTTP-01) | DNS plugin name
    DnsPluginArgs     = @{}                       # plugin args for DNS-01
    CertStore         = 'WebHosting'             # drives import + binding + label
    PostDeployHook    = ''                         # optional .ps1 for non-IIS deploy; empty = off
    RenewalDaysBefore = 30
}

# ------------------------------------------------------------
# Dot-source Private then Public
# ------------------------------------------------------------

$privateFiles = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue)
$publicFiles  = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public')  -Filter '*.ps1' -ErrorAction SilentlyContinue)

foreach ($file in @($privateFiles + $publicFiles)) {
    . $file.FullName
}

Export-ModuleMember -Function 'Start-TUACME'
