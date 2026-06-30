<#
    launch.ps1 - Harness used by the tui-test specs to drive the interactive TUI.

    tui-test starts this script in a real pty (pwsh -NoProfile -File launch.ps1).
    Every state path is pointed at a throwaway temp directory so the suite never
    touches a developer's real %ProgramData%\TU-ACME store. Pass -DryRun to
    exercise the Dry-Run banner.

    Menu mode (default): import the module and launch the interactive menu. The
    module is portable, so off Windows the elevation/IIS/ACL prerequisites in
    Bootstrap.ps1 self-skip and the menu loop is reached without admin or IIS.

    Integration mode (when $env:TUACME_ACME_DIRECTORY is set): additionally
    pre-stage a Posh-ACME server + account in the shared home the wizard will
    use, and write a config.json that targets that server with the DNS test
    plugin (ChallTestSrv). This lets the N wizard issue a real certificate
    end-to-end against the test ACME server (Pebble) in CI. This path is
    Windows-only because PowerShell's Read-Host only receives pty input there.
#>
[CmdletBinding()]
param(
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Isolate all TU-ACME state under a per-run temp directory. The module derives
# its ProgramData paths from $env:ProgramData at import time, so set it first.
$programData = Join-Path ([IO.Path]::GetTempPath()) ("TU-ACME-tuitest-" + [Guid]::NewGuid().ToString('N'))
$env:ProgramData = $programData
$tuRoot = Join-Path $programData 'TU-ACME'
New-Item -ItemType Directory -Path $tuRoot -Force | Out-Null

if ($env:TUACME_ACME_DIRECTORY) {
    # Best-effort: never let integration setup stop the menu from launching, so
    # the menu-navigation specs still run even if the test ACME server is down.
    try {
        $acmeHome = Join-Path $tuRoot 'ACME'
        New-Item -ItemType Directory -Path $acmeHome -Force | Out-Null
        # The wizard issues against whatever POSHACME_HOME the module activates,
        # which is exactly this path (ProgramData\TU-ACME\ACME). Stage the
        # account here so New-PACertificate finds an existing, TOS-accepted one.
        $env:POSHACME_HOME = $acmeHome
        if ([string]::IsNullOrWhiteSpace($env:POSHACME_PLUGINS)) {
            $env:POSHACME_PLUGINS = Join-Path $PSScriptRoot '../Integration/plugins'
        }

        Import-Module Posh-ACME -Force
        # -SkipCertificateCheck is persisted on the server, so the wizard's later
        # bare Set-PAServer <url> keeps trusting Pebble's self-signed certificate.
        Set-PAServer -DirectoryUrl $env:TUACME_ACME_DIRECTORY -SkipCertificateCheck | Out-Null
        if (-not (Get-PAAccount)) {
            New-PAAccount -Contact 'tuacme-tui@example.com' -AcceptTOS -Force | Out-Null
        }

        $cts = if ($env:TUACME_CHALLTESTSRV) { $env:TUACME_CHALLTESTSRV } else { 'http://localhost:8055' }
        $config = [ordered]@{
            ACMEServer        = $env:TUACME_ACME_DIRECTORY
            ContactEmail      = 'tuacme-tui@example.com'
            ValidationPlugin  = 'ChallTestSrv'
            PluginArgs        = @{ CTSMgmtUri = $cts }
            CertStore         = 'My'
            PostDeployHook    = ''
            RenewalDaysBefore = 30
        }
        $config | ConvertTo-Json -Depth 6 |
            Set-Content -Path (Join-Path $tuRoot 'config.json') -Encoding UTF8
    } catch {
        Write-Warning "TUI integration setup failed (menu specs unaffected): $_"
    }
}

$modulePath = Join-Path $PSScriptRoot '../../src/TU-ACME.psd1'
Import-Module $modulePath -Force

if ($DryRun) {
    Start-TUACME -DryRun
} else {
    Start-TUACME
}
