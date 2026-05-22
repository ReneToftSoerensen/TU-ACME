# Platform detection — available to all Private/Public functions via $script:OnWindows
$script:OnWindows = if (Test-Path variable:IsWindows) { $IsWindows } else { $true }

# Env-var fallbacks for Linux/macOS (set once at module load time)
if (-not $env:ProgramData)  { $env:ProgramData  = Join-Path ([System.IO.Path]::GetTempPath()) 'TU-ACME' }
if (-not $env:ProgramFiles) { $env:ProgramFiles = [System.IO.Path]::GetTempPath() }
if (-not $env:LOCALAPPDATA) { $env:LOCALAPPDATA = Join-Path ([System.IO.Path]::GetTempPath()) 'TU-ACME-Local' }
if (-not $env:COMPUTERNAME) { $env:COMPUTERNAME = [System.Net.Dns]::GetHostName() }

# Redirect Posh-ACME's data store to a machine-wide ProgramData path
# BEFORE we import Posh-ACME below. Posh-ACME reads POSHACME_HOME on
# Import-Module to resolve the store root, then caches it for the
# session - so the env var has to be in place first.
. (Join-Path $PSScriptRoot 'Private\Helpers\Initialize-TUACMEStore.ps1')
Initialize-TUACMEStore | Out-Null

# Eagerly import Posh-ACME at the top of module load. The PA-logging
# proxies installed below by Initialize-PALogging need to resolve
# 'Posh-ACME\<cmd>' at runtime; importing here ensures Posh-ACME is in
# TU-ACME's module session state before any of our code runs.
#
# Why not just rely on Initialize-PALogging's own Import-Module call?
# On PS 5.1, "Import-Module Posh-ACME -Global" issued from inside a
# nested function during another module's load doesn't reliably make
# the module's commands resolvable from the proxy bodies on first call
# — the user has to do "Import-Module Posh-ACME -Force" themselves
# before "Start-TUACME" works. Doing it here, at the top of the .psm1,
# before any function definitions or proxy installation, sidesteps that.
if (Get-Module -ListAvailable -Name 'Posh-ACME') {
    try {
        # -Force matters here: if Posh-ACME was loaded earlier in the
        # session (e.g. the user dot-sourced or imported it manually
        # before Import-Module TU-ACME), Posh-ACME has already cached
        # its store root from whatever POSHACME_HOME was at THAT
        # moment - usually undefined, falling back to the per-user
        # %LOCALAPPDATA%\Posh-ACME path. A plain Import-Module is a
        # no-op against an already-loaded module and would not
        # re-read the env var. -Force tears it down and reloads,
        # picking up the value Initialize-TUACMEStore set above.
        Import-Module Posh-ACME -Force -ErrorAction Stop
    } catch {
        Write-Warning "TU-ACME: Could not import Posh-ACME at module load: $($_.Exception.Message)"
    }
}

$Private = @(Get-ChildItem -Path "$PSScriptRoot\Private" -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue)
$Public  = @(Get-ChildItem -Path "$PSScriptRoot\Public"  -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue)

foreach ($file in ($Private + $Public)) {
    try   { . $file.FullName }
    catch { Write-Error "Failed to dot-source $($file.FullName): $_" }
}

# Install logging proxies for every Posh-ACME cmdlet TU-ACME calls so
# we have an audit trail under $env:ProgramData\TU-ACME\posh-acme.log.
# Must run after the helpers above are dot-sourced.
Initialize-PALogging

Export-ModuleMember -Function $Public.BaseName
