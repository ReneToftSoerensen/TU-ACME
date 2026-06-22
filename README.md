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
| `DnsPluginArgs`     | `@{}`                      | Plugin args for DNS-01 validation.                          |
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
