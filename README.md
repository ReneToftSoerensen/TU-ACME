# TU-ACME

TU-ACME is a Windows-only, interactive terminal UI (TUI) over
[Posh-ACME](https://github.com/rmbolger/Posh-ACME) 4.x for issuing and renewing
certificates against an internal ACME CA, with IIS binding integration. It is a
PowerShell 7 module whose single entry point is `Start-TUACME`.

The terminal UI mirrors the WACS / Simple-ACME workflow: pick IIS sites, filter
hosts, choose a common name, issue, then re-point the IIS HTTPS bindings — all
from a keyboard-driven menu.

> A headless renewal runner (`PoshAcme-Renew.ps1`, driven by a SYSTEM scheduled
> task) is specified in `ISSUE-02-renewal-runner.md` and is a follow-up. This
> repository already ships the shared deployment seam (`Private/Deploy.ps1`) and
> the scheduled-task registration the runner will use.

## Requirements

- Windows Server 2019+ / Windows 10+ with IIS installed.
- **PowerShell 7.0+**, run **elevated** (administrator required).
- Runtime modules (installed `-Scope AllUsers`):
  - `Posh-ACME` (>= 4.0)
  - `IISAdministration`

> These two modules are runtime dependencies but are intentionally **not** listed
> in the manifest's `RequiredModules`, so the module can be imported and analyzed
> on non-Windows CI. Install them yourself on the target server (see below).

## Install

```powershell
# On the target Windows server, elevated:
Install-Module Posh-ACME -MinimumVersion 4.0 -Scope AllUsers
Install-Module IISAdministration -Scope AllUsers

# Import this module:
Import-Module .\src\TU-ACME.psd1 -Force
```

## Run

```powershell
Start-TUACME            # interactive TUI
Start-TUACME -DryRun    # print the equivalent commands, make no changes
Start-TUACME -WhatIf    # forward -WhatIf to ShouldProcess-aware operations
```

### Main menu

| Key | Action                                                            |
| --- | ----------------------------------------------------------------- |
| `N` | Create certificate (full 6-step wizard)                           |
| `M` | Manage renewals (view / force-renew single / renew all / delete)  |
| `B` | Browse IIS bindings                                               |
| `S` | Manage ACME accounts                                              |
| `T` | Manage scheduled renewal tasks                                    |
| `Q` | Quit                                                              |

Dry-Run and What-If are **switches** on `Start-TUACME` (`-DryRun` / `-WhatIf`),
not on-screen toggles.

## State and paths

All state lives under `%ProgramData%\TU-ACME\`:

| Path                                   | Purpose                                  |
| -------------------------------------- | ---------------------------------------- |
| `%ProgramData%\TU-ACME\config.json`    | TU-ACME configuration                    |
| `%ProgramData%\TU-ACME\ACME`           | Posh-ACME home (`POSHACME_HOME`)         |
| `%ProgramData%\TU-ACME\renewal.log`    | Shared ISO-8601 log (TUI + runner)       |

On first run, `Initialize-TUACMEHome`:

- Creates `%ProgramData%\TU-ACME\` and the `ACME` subfolder.
- Applies an ACL: **Administrators** and **SYSTEM** Full control, **Users**
  Read & Execute (so the SYSTEM scheduled task can read the same account state).
- Sets `POSHACME_HOME` at **machine** and **process** scope and re-imports
  Posh-ACME so it picks up the shared home. No migration of any prior location
  is performed.

## Configuration (`config.json`)

| Key                 | Default                    | Notes                                                       |
| ------------------- | -------------------------- | ----------------------------------------------------------- |
| `ACMEServer`        | `acme.fragt.root.local`    | Built-in alias, custom server short name, or directory URL. |
| `ContactEmail`      | *(empty)*                  | Account contact email.                                      |
| `ValidationPlugin`  | `WebSelfHost`              | Passed via `-Plugin` (HTTP-01 self-host or a DNS plugin).   |
| `PluginArgs`        | `@{}`                      | Passed via `-PluginArgs` (e.g. credentials for a DNS plugin). |
| `CertStore`         | `WebHosting`               | Single source of truth: drives import store, binding store, and the UI label. |
| `PostDeployHook`    | *(empty)*                  | Optional `.ps1` for non-IIS deployment targets.             |
| `RenewalDaysBefore` | `30`                       | Renew this many days before expiry.                         |

## Development

```powershell
Import-Module .\src\TU-ACME.psd1 -Force
Invoke-ScriptAnalyzer -Path .\src -Recurse -Settings .\PSScriptAnalyzerSettings.psd1   # must be clean
Invoke-Pester .\tests
```

CI runs the analyzer and the Pester suite on `windows-latest`
(`.github/workflows/ci.yml`). Live IIS / Posh-ACME paths are exercised by mocks
only; full integration is manual on Windows (e.g. against a Pebble/Boulder test
CA).

### Terminal UI (TUI) tests

`tests/Tui/` drives the live interactive menu (`Start-TUACME`) through a real
terminal with [tui-test](https://github.com/Factory-AI/tui-test). The specs spawn
`pwsh` running `launch.ps1` (which isolates all state under a temp directory) and
assert on the rendered menu:

```powershell
cd tests/Tui
npm ci
npx '@microsoft/tui-test'
```

> Run these on **Windows**. PowerShell's `Read-Host` only receives terminal
> keystrokes under Windows' conpty, so on Linux/macOS the menu renders but cannot
> be driven (only the banner / Dry-Run specs pass there).

The menu-navigation specs (`menu.test.ts`, `dryrun.test.ts`) need only the
module. `integration.test.ts` is a full end-to-end test that drives the 6-step
wizard to issue a **real** certificate; it self-enables only when CI has
provisioned an IIS site with a host-header HTTP binding (`TUACME_TUI_HOST`) and a
test ACME server (`TUACME_ACME_DIRECTORY`), and is otherwise skipped. CI runs the
whole suite on every pull request, reusing the same Pebble + `challtestsrv`
servers as the Pester integration test.

### Full-scale integration test

`tests/Integration/TU-ACME.Integration.Tests.ps1` is an opt-in, end-to-end test
that issues a **real** certificate against a test ACME server
([Pebble](https://github.com/letsencrypt/pebble) + `pebble-challtestsrv`) and
then exercises the module's live Posh-ACME helpers (server resolution, account
and order enumeration, ISO-8601 date formatting, invalid-order detection). It
self-skips unless `TUACME_ACME_DIRECTORY` is set, so it never affects the
mocked unit run. Because of this, a plain `Invoke-Pester ./tests` (locally or in
CI) runs the integration suite only when those environment variables point at a
reachable test ACME server, and runs just the mocked unit tests otherwise.

CI runs it automatically in the single `build` job on `windows-latest`, which
downloads the native Pebble and `pebble-challtestsrv` Windows binaries and runs
them as background processes (no Docker). To run it locally on Windows, download
the matching release from
[Pebble releases](https://github.com/letsencrypt/pebble/releases), generate a
short-lived self-signed TLS certificate for Pebble, and then start both servers:

```powershell
# pebble-challtestsrv answers DNS-01 and exposes the management API on :8055.
Start-Process .\pebble-challtestsrv.exe -ArgumentList `
  '-management :8055 -dnsserver :8053 -http01 "" -https01 "" -tlsalpn01 "" -doh ""'

$pebbleTls = Join-Path $PWD 'pebble-tls'
New-Item -ItemType Directory -Path $pebbleTls -Force | Out-Null
$key = [System.Security.Cryptography.RSA]::Create(2048)
$request = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
  'CN=localhost',
  $key,
  [System.Security.Cryptography.HashAlgorithmName]::SHA256,
  [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
)
$sanBuilder = [System.Security.Cryptography.X509Certificates.SubjectAlternativeNameBuilder]::new()
$sanBuilder.AddDnsName('localhost')
$sanBuilder.AddIpAddress([System.Net.IPAddress]::Loopback)
$request.CertificateExtensions.Add($sanBuilder.Build())
$cert = $request.CreateSelfSigned([System.DateTimeOffset]::UtcNow.AddDays(-1), [System.DateTimeOffset]::UtcNow.AddDays(7))
$certPath = Join-Path $pebbleTls 'pebble-cert.pem'
$keyPath = Join-Path $pebbleTls 'pebble-key.pem'
Set-Content -Path $certPath -Value $cert.ExportCertificatePem() -NoNewline
Set-Content -Path $keyPath -Value $key.ExportPkcs8PrivateKeyPem() -NoNewline

$config = Get-Content .\tests\Integration\pebble-config.json -Raw | ConvertFrom-Json
$config.pebble | Add-Member -NotePropertyName certificate -NotePropertyValue $certPath
$config.pebble | Add-Member -NotePropertyName privateKey -NotePropertyValue $keyPath
$config | ConvertTo-Json -Depth 5 | Set-Content .\pebble-config.runtime.json -Encoding UTF8

$env:PEBBLE_VA_NOSLEEP = '1'
Start-Process .\pebble.exe -ArgumentList `
  '-config .\pebble-config.runtime.json -dnsserver 127.0.0.1:8053'
```

```powershell
$env:TUACME_ACME_DIRECTORY = 'https://localhost:14000/dir'
$env:TUACME_CHALLTESTSRV   = 'http://localhost:8055'
$env:POSHACME_PLUGINS      = "$PWD/tests/Integration/plugins"
$config = New-PesterConfiguration
$config.Run.Path = './tests/Integration'
$config.Filter.Tag = 'Integration'
Invoke-Pester -Configuration $config
```
