<#
.SYNOPSIS
    Builds a CA trust bundle (system roots + Pebble's static directory cert)
    at tests/.tools/<pebble-version>/trust-bundle.crt. No-op on Windows.

.DESCRIPTION
    Integration tests on Linux need SSL_CERT_FILE to point at a bundle
    containing tests/.pebble/cert.pem because .NET caches its OpenSSL trust
    at process startup. This script generates the bundle deterministically
    so CI can cache the entire tests/.tools/<ver>/ directory in one key.

    Run once before launching integration tests:
        pwsh tests/Install-Pebble.ps1
        pwsh tests/Build-PebbleBundle.ps1
        SSL_CERT_FILE=tests/.tools/v2.10.1/trust-bundle.crt pwsh -c 'Invoke-Pester ./tests -Tag Integration'
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

if ($IsWindows -or $env:OS -eq 'Windows_NT') {
    Write-Host "Windows: trust bundle not needed (Cert:\CurrentUser\Root handled by Install-TrustedPebbleRoot)." -ForegroundColor DarkGray
    return
}

$toolsRoot = Join-Path $repoRoot 'tests/.tools'
if (-not (Test-Path $toolsRoot)) {
    throw "Pebble tools dir not found at $toolsRoot. Run tests/Install-Pebble.ps1 first."
}
$versionDir = Get-ChildItem -Path $toolsRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
if (-not $versionDir) { throw "No pebble version directory found under $toolsRoot." }

$pebbleCert = Join-Path $repoRoot 'tests/.pebble/cert.pem'
if (-not (Test-Path $pebbleCert)) {
    throw "Pebble static directory cert not found at $pebbleCert."
}

$systemBundle = '/etc/ssl/certs/ca-certificates.crt'
if (-not (Test-Path $systemBundle)) {
    throw "System CA bundle not found at $systemBundle (expected on Debian/Ubuntu)."
}

$outPath = Join-Path $versionDir.FullName 'trust-bundle.crt'
$content = (Get-Content -Path $systemBundle -Raw) + "`n" + (Get-Content -Path $pebbleCert -Raw)
Set-Content -Path $outPath -Value $content -Encoding Ascii

Write-Host "Trust bundle written: $outPath" -ForegroundColor Green
Write-Host "Set SSL_CERT_FILE=$outPath before launching pwsh for integration tests." -ForegroundColor DarkGray
