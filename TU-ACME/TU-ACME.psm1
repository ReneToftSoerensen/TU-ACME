# Platform detection — available to all Private/Public functions via $script:OnWindows
$script:OnWindows = if (Test-Path variable:IsWindows) { $IsWindows } else { $true }

# Env-var fallbacks for Linux/macOS (set once at module load time)
if (-not $env:ProgramData)  { $env:ProgramData  = Join-Path ([System.IO.Path]::GetTempPath()) 'TU-ACME' }
if (-not $env:ProgramFiles) { $env:ProgramFiles = [System.IO.Path]::GetTempPath() }
if (-not $env:LOCALAPPDATA) { $env:LOCALAPPDATA = Join-Path ([System.IO.Path]::GetTempPath()) 'TU-ACME-Local' }
if (-not $env:COMPUTERNAME) { $env:COMPUTERNAME = [System.Net.Dns]::GetHostName() }

$Private = @(Get-ChildItem -Path "$PSScriptRoot\Private" -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue)
$Public  = @(Get-ChildItem -Path "$PSScriptRoot\Public"  -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue)

foreach ($file in ($Private + $Public)) {
    try   { . $file.FullName }
    catch { Write-Error "Failed to dot-source $($file.FullName): $_" }
}

Export-ModuleMember -Function $Public.BaseName
