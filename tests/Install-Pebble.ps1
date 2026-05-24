<#
.SYNOPSIS
    Downloads the Pebble ACME test server binaries into tests/.tools/<version>/.
    Idempotent — skips work if the target dir already has both binaries.

.DESCRIPTION
    Pebble is letsencrypt/pebble: a single-binary in-memory ACME v2 server,
    intended for client-side conformance testing. We use it for the
    Integration tier so we don't need a real ACME CA in CI.

    The binaries are pinned by -Version (default v2.10.1). CI should cache
    tests/.tools/<version>/ keyed by this version + OS.

.PARAMETER Version
    Pebble release tag, e.g. v2.10.1.

.EXAMPLE
    pwsh ./tests/Install-Pebble.ps1
#>
[CmdletBinding()]
param(
    [string] $Version = 'v2.10.1'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$target   = Join-Path $repoRoot "tests/.tools/$Version"
New-Item -ItemType Directory -Path $target -Force | Out-Null

$os, $arch = if ($IsWindows -or ($env:OS -eq 'Windows_NT')) { 'windows','amd64' }
             elseif ($IsMacOS) { 'darwin','amd64' }
             else { 'linux','amd64' }

$assets = @(
    @{ Name = 'pebble';              File = "pebble-${os}-${arch}.tar.gz" }
    @{ Name = 'pebble-challtestsrv'; File = "pebble-challtestsrv-${os}-${arch}.tar.gz" }
)

foreach ($a in $assets) {
    $exeName = if ($os -eq 'windows') { "$($a.Name).exe" } else { $a.Name }
    $exePath = Join-Path $target $exeName
    if (Test-Path $exePath) {
        Write-Host "  [skip] $exeName already present" -ForegroundColor DarkGray
        continue
    }

    $url = "https://github.com/letsencrypt/pebble/releases/download/$Version/$($a.File)"
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) $a.File
    Write-Host "  [get]  $url"
    Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing

    $extractDir = Join-Path ([System.IO.Path]::GetTempPath()) ($a.Name + '-extract-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
    tar -xzf $tmp -C $extractDir
    $found = Get-ChildItem -Path $extractDir -Recurse -Filter $exeName | Select-Object -First 1
    if (-not $found) { throw "Could not find $exeName inside $tmp" }
    Copy-Item -Path $found.FullName -Destination $exePath -Force
    if (-not $IsWindows -and ($env:OS -ne 'Windows_NT')) {
        chmod +x $exePath
    }
    Remove-Item -Path $tmp, $extractDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Pebble $Version installed under tests/.tools/$Version/" -ForegroundColor Green
Get-ChildItem -Path $target | Format-Table Name, Length -AutoSize
