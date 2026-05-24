# Helper module for integration tests that need a live ACME server.
#
# Pebble (letsencrypt/pebble) is a single-binary in-memory ACME v2 server
# intended for client-side conformance testing. TU-ACME's Integration tier
# spawns two Pebble instances — one for the prod URL, one for the staging
# URL — so the wizard can register both accounts end-to-end without the
# duplicate-account ShouldContinue prompt firing.
#
# Trust:
#   Pebble's ACME endpoint serves a self-signed cert we generated under
#   tests/.pebble/cert.pem. .NET on Linux caches its OpenSSL trust at
#   process startup, so SSL_CERT_FILE has to be set BEFORE pwsh launches
#   (e.g. by tests/Run-PesterIntegration.ps1). On Windows, .NET reads the
#   Cert:\CurrentUser\Root store live, so Install-TrustedPebbleRoot can
#   import the PEM at test time.

function Get-PebbleBinary {
    [CmdletBinding()]
    param()

    $repoRoot = Resolve-Path "$PSScriptRoot\..\.."
    $toolsRoot = Join-Path $repoRoot 'tests/.tools'
    if (-not (Test-Path $toolsRoot)) {
        throw "Pebble tools dir not found at $toolsRoot. Run tests/Install-Pebble.ps1 first."
    }
    $versionDir = Get-ChildItem -Path $toolsRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $versionDir) { throw "No pebble version directory found under $toolsRoot." }
    $exe = if ($IsWindows -or $env:OS -eq 'Windows_NT') { 'pebble.exe' } else { 'pebble' }
    $binary = Join-Path $versionDir.FullName $exe
    if (-not (Test-Path $binary)) { throw "Pebble binary not found at $binary." }
    return $binary
}

function Assert-PebbleTrust {
    <#
    .SYNOPSIS
        Sanity-check that pwsh's TLS provider will trust Pebble's static
        directory cert. Throws with a remediation hint if it won't.
    #>
    [CmdletBinding()]
    param()

    if ($IsWindows -or $env:OS -eq 'Windows_NT') { return }   # handled by Install-TrustedPebbleRoot

    $repoRoot   = Resolve-Path "$PSScriptRoot\..\.."
    $pebbleCert = Join-Path $repoRoot 'tests/.pebble/cert.pem'
    $bundle     = $env:SSL_CERT_FILE
    if (-not $bundle -or -not (Test-Path $bundle)) {
        throw "SSL_CERT_FILE is not set (or points at a missing file). On Linux, integration tests need a CA bundle that includes Pebble's self-signed cert. Run: pwsh tests/Build-PebbleBundle.ps1; then relaunch pwsh with SSL_CERT_FILE=tests/.tools/<ver>/trust-bundle.crt."
    }
    $bundleContent = Get-Content -Path $bundle -Raw
    $pebbleContent = Get-Content -Path $pebbleCert -Raw
    if (-not $bundleContent.Contains(($pebbleContent -split "`n")[1])) {
        throw "SSL_CERT_FILE=$bundle does not contain Pebble's static directory cert ($pebbleCert). Re-run tests/Build-PebbleBundle.ps1."
    }
}

function Start-PebbleServer {
    [CmdletBinding()]
    param(
        [ValidateSet('Prod','Staging')]
        [string] $Role = 'Prod',
        [int]    $ReadyTimeoutSeconds = 15
    )

    Assert-PebbleTrust

    $binary    = Get-PebbleBinary
    $repoRoot  = Resolve-Path "$PSScriptRoot\..\.."
    $logPath   = Join-Path ([System.IO.Path]::GetTempPath()) ("pebble-$Role-" + [guid]::NewGuid().ToString('N') + ".log")

    $configRel, $port = if ($Role -eq 'Staging') { 'tests/.pebble/pebble-config-staging.json', 14001 }
                        else                     { 'tests/.pebble/pebble-config.json',         14000 }

    $env:PEBBLE_VA_NOSLEEP = '1'
    $env:PEBBLE_VA_ALWAYS_VALID = '1'

    $proc = Start-Process -FilePath $binary `
        -ArgumentList @('-config', $configRel) `
        -WorkingDirectory $repoRoot `
        -RedirectStandardOutput $logPath `
        -RedirectStandardError ($logPath + '.err') `
        -PassThru -NoNewWindow

    $directoryUrl = "https://localhost:$port/dir"

    # The readiness probe needs to ignore the untrusted self-signed cert
    # Pebble serves. pwsh 7+ accepts -SkipCertificateCheck on Invoke-WebRequest;
    # Windows PowerShell 5.1 has no such parameter, so we set the legacy
    # ServicePointManager callback there. (.NET HttpClient on pwsh 7 ignores
    # the callback, hence the per-runtime split.)
    $useSkipParam  = $PSVersionTable.PSEdition -eq 'Core'
    $prevCallback  = $null
    $prevProtocol  = $null
    if (-not $useSkipParam) {
        # Windows PowerShell 5.1: cert callback to accept Pebble's self-signed cert,
        # AND force TLS 1.2 because the .NET Framework default on stock Windows
        # Server can still be SSL3/TLS1.0 which Pebble rejects.
        $prevCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        $prevProtocol = [System.Net.ServicePointManager]::SecurityProtocol
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    }

    $deadline = (Get-Date).AddSeconds($ReadyTimeoutSeconds)
    $ready = $false
    $lastErr = $null
    try {
        while ((Get-Date) -lt $deadline) {
            try {
                $params = @{ Uri = $directoryUrl; Method = 'Get'; UseBasicParsing = $true; TimeoutSec = 2; ErrorAction = 'Stop' }
                if ($useSkipParam) { $params['SkipCertificateCheck'] = $true }
                $resp = Invoke-WebRequest @params
                if ($resp.StatusCode -eq 200) { $ready = $true; break }
            } catch {
                $lastErr = $_.Exception.Message
                Start-Sleep -Milliseconds 250
            }
        }
    } finally {
        if (-not $useSkipParam) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $prevCallback
            if ($null -ne $prevProtocol) {
                [System.Net.ServicePointManager]::SecurityProtocol = $prevProtocol
            }
        }
    }

    if (-not $ready) {
        $tail = if (Test-Path $logPath) { (Get-Content $logPath -Tail 30) -join [Environment]::NewLine } else { '(no log)' }
        $errTail = if (Test-Path ($logPath + '.err')) { (Get-Content ($logPath + '.err') -Tail 30) -join [Environment]::NewLine } else { '' }
        try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
        Write-Host "[Pebble] Probe last error: $lastErr" -ForegroundColor Yellow
        Write-Host "[Pebble] stdout tail ($logPath):" -ForegroundColor Yellow
        Write-Host $tail
        if ($errTail) {
            Write-Host "[Pebble] stderr tail:" -ForegroundColor Yellow
            Write-Host $errTail
        }
        throw "Pebble ($Role) did not become ready within $ReadyTimeoutSeconds s. Last probe error: $lastErr"
    }

    $trustInfo = $null
    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        $trustInfo = Install-TrustedPebbleRoot -DirectoryCertPath (Join-Path $repoRoot 'tests/.pebble/cert.pem')
    }

    return [PSCustomObject]@{
        Process      = $proc
        Pid          = $proc.Id
        Role         = $Role
        DirectoryUrl = $directoryUrl
        LogPath      = $logPath
        TrustInfo    = $trustInfo
    }
}

function Install-TrustedPebbleRoot {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $DirectoryCertPath)

    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        $imported = Import-Certificate -FilePath $DirectoryCertPath -CertStoreLocation 'Cert:\CurrentUser\Root' -ErrorAction Stop
        return [PSCustomObject]@{ OS = 'Windows'; Thumbprint = $imported.Thumbprint }
    }
    return $null   # Linux: trust comes from SSL_CERT_FILE, set before pwsh launch.
}

function Uninstall-TrustedPebbleRoot {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $TrustInfo)

    if (-not $TrustInfo) { return }
    if ($TrustInfo.OS -eq 'Windows') {
        Get-ChildItem 'Cert:\CurrentUser\Root' | Where-Object Thumbprint -eq $TrustInfo.Thumbprint | Remove-Item -ErrorAction SilentlyContinue
    }
}

function Stop-PebbleServer {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Info)

    if ($Info -and $Info.Pid) {
        try { Stop-Process -Id $Info.Pid -Force -ErrorAction SilentlyContinue } catch {}
    }
    if ($Info -and $Info.TrustInfo) {
        Uninstall-TrustedPebbleRoot -TrustInfo $Info.TrustInfo
    }
}

Export-ModuleMember -Function Get-PebbleBinary, Assert-PebbleTrust, Start-PebbleServer, Stop-PebbleServer, Install-TrustedPebbleRoot, Uninstall-TrustedPebbleRoot
