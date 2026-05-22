# CLAUDE.md — TU-ACME

## Project description
An interactive text-based terminal user interface (TUI) for the PowerShell module Posh-ACME. The project gives system administrators a fully menu-driven interface for managing ACME/Let's Encrypt certificates on Windows servers, including IIS integration and automatic renewal.

## Platform and minimum requirements
- **OS:** Windows (client and server, including Windows Server Core)
- **PowerShell:** 5.0 minimum (matches Posh-ACME's own minimum requirement)
- **Runtime environment:** Directly in an existing console session — no graphical dependencies
- **Remoting:** Supports PowerShell Remoting (WinRM/SSH) on headless systems

## Folder structure
```
TU-ACME/
├── CLAUDE.md               # This file
├── README.md               # Project documentation
├── Usecases/               # Granular use case documents (UC-X.Y)
│   ├── UC-0.1-*.md         # System
│   ├── UC-1.x-*.md         # Account management
│   ├── UC-2.x-*.md         # Certificate ordering
│   ├── UC-3.x-*.md         # DNS plugins and credentials
│   ├── UC-4.x-*.md         # Dashboard
│   ├── UC-5.x-*.md         # Automation
│   ├── UC-6.x-*.md         # Export and Import
│   ├── UC-7.x-*.md         # Troubleshooting
│   └── UC-8.x-*.md         # IIS Integration
└── Scripts/                # PowerShell scripts (implementation)
    ├── Start-TUACME.ps1
    └── Posh-ACME-IIS-Plugin.ps1
```

## Technical stack
| Component | Choice |
|---|---|
| Runtime | Windows PowerShell **5.1** (only) |
| TUI engine | Pure console I/O — `[Console]::ReadKey()`, `$Host.UI.RawUI` |
| Distribution | PowerShell module (`.psm1` + `.psd1`) |
| Install path | `$env:ProgramFiles\WindowsPowerShell\Modules\TU-ACME\` (AllUsers) |
| Configuration | JSON (`$env:ProgramData\TU-ACME\config.json`) |
| Posh-ACME store | `$env:ProgramData\TU-ACME\Posh-ACME\` (machine-wide via `POSHACME_HOME`; ACL: Administrators + SYSTEM Full Control) |
| Secret data | `Export-Clixml` DPAPI encryption (`.xml`) |
| Email | `Send-MailMessage` plaintext |
| IIS scope | Local IIS with thumbprint matching |
| Logging | Windows Event Log (Application / source: `TU-ACME`) |

See `Usecases/UC-0.0-Teknisk-Stack-og-Specs.md` for full details, code examples, and folder structure.

Always use UTF-8 BOM

## Architecture principles
- **Pure TUI pattern:** All interaction takes place through text-based menus, table views, and prompts in the terminal. No GUI dependencies.
- **Wrapper architecture:** The TUI calls Posh-ACME commands directly. No business logic is duplicated — Posh-ACME is the source of truth.
- **Security first:** Sensitive data (API keys, SMTP passwords) is never stored in plain text. Always use `SecureString` and DPAPI (`Export-Clixml`).
- **Headless compatibility:** Background scripts run with `-NonInteractive -WindowStyle Hidden` and use the Windows Event Log for output.

## User roles
| Role | Access |
|---|---|
| **System administrator (Admin)** | Full access — configuration, ordering, automation, IIS |
| **Monitor/Technician (ReadOnly)** | Dashboard only (UC-4.x) and log viewing (UC-7.1) |

## Key use cases (prioritized)
All use cases are documented in the `Usecases/` folder. High-priority cases:
- **UC-0.1** — Privilege check at startup (foundation for all admin functions)
- **UC-2.2** — Certificate ordering with real-time spinner
- **UC-4.1** — Color-coded certificate dashboard
- **UC-5.1 + UC-5.4** — Automatic renewal via Task Scheduler
- **UC-8.3 + UC-8.4** — Automatic IIS update via post-renewal plugin

## Important PowerShell commands
```powershell
# Account management
Get-PAAccount -List
New-PACAccount -AcceptTOS -Contact "mail@eks.dk"
Set-PAAccount -ID "<id>"

# Certificates
Get-PACertificate -List
New-PACertificate -Domain "eks.dk" -Plugin Cloudflare -PluginArgs $args
Submit-Renewal

# IIS
Import-Module WebAdministration
Get-WebBinding -Protocol "https"
Set-WebBinding -Name "<site>" -PropertyName "certificateHash" -Value $thumbprint

# Automation
Register-ScheduledTask -TaskName "Posh-ACME-AutoRenewal" ...
# IIS rebind on renewal is wired into Invoke-RenewalBackground.ps1
# (Posh-ACME v4 has no -PostScript hook).
```

## Security guidelines
- Always use `Read-Host -AsSecureString` for passwords and API keys — never plain `Read-Host`.
- Store only encrypted: `Export-Clixml` (DPAPI-based, machine/user-bound).
- Check administrator privileges at startup (UC-0.1) — disable admin menus if not elevated.
- Log to the Windows Event Log in background scripts — never to plain-text files containing credentials.

## File encoding
All `.ps1`, `.psm1`, and `.psd1` files in the repository **must** be saved as **UTF-8 with BOM** (Byte Order Mark, `EF BB BF`).
- Windows PowerShell 5.1 expects a UTF-8 BOM for correct handling of non-ASCII characters (e.g. Danish letters ae, oe, aa).
- Without a BOM, PS 5.1 may misinterpret the file as Windows-1252, which corrupts strings containing diacritics.
- Verify with: `(Get-Content -Path file.ps1 -Raw -Encoding Byte)[0..2] | ForEach-Object { '{0:X2}' -f $_ }` → must show `EF BB BF`.
- When creating new files: save explicitly as UTF-8 BOM in your editor, or use `$content | Set-Content -Path file.ps1 -Encoding UTF8` in PowerShell (PS 5.1's `UTF8` includes the BOM).

## Language
- Always respond, write code, write comments, write commit messages, and write documentation in **English**, even when the user writes in Danish or another language. The repository is English-only.

## Development workflow
1. All use cases are atomic and can be implemented independently.
2. Use `claude/posh-acme-tui-specs-9Sbhg` as the development branch.
3. **Always run the test suite (`Invoke-Pester ./tests`) before committing.** If tests fail, fix them before committing — never commit with failing tests.
4. Commit frequently with descriptive commit messages in English.
5. Test TUI input/output manually in a PowerShell 5.1 session before pushing.
6. All new `.ps1`/`.psm1`/`.psd1` files must have a UTF-8 BOM (see **File encoding** above).
7. **Always bump the version** before pushing user-visible changes. See **Versioning** below for the rules and the exact files to update.

## Versioning
The project follows semver. Pre-1.0 releases use `0.MINOR.PATCH`:
- **PATCH** (`0.1.0` → `0.1.1`) — bug fixes, internal refactors, doc-only edits, CI changes.
- **MINOR** (`0.1.0` → `0.2.0`) — new user-visible features, behavior changes, new menu options, new prompts.
- **MAJOR** (`0.x.y` → `1.0.0`) — first production-ready release; bump only after the full SMOKE-TEST checklist passes on Windows.

When bumping the version, update **all** of the following references in a single commit:

| File | Line / context |
|---|---|
| `TU-ACME/TU-ACME.psd1` | `ModuleVersion = '<new>'` (top of file) |
| `TU-ACME/Private/Helpers/Get-TUACMEConfig.ps1` | `Version = '<new>'` inside the `$defaults` hashtable |
| `TU-ACME/Public/Start-TUACME.ps1` | `Show-Menu -Title 'TU-ACME v<new> — Certificate Management'` |
| `TU-ACME/Private/Automation/Invoke-SMTPConfig.ps1` | `Version:     <new>` in the test-mail body heredoc |
| `README.md` | `TU-ACME v<new>` in the usage example |
| `INSTALL.md` | `Script      <new>    TU-ACME   Start-TUACME` in the verify output |
| `SMOKE-TEST.md` | `TU-ACME v<new> - Certificate Management` in section 1 |

Verify no stragglers with:
```powershell
git grep '<old-version>'   # must return only changelog/history references
```

After bumping, re-install the module so `Get-Module -ListAvailable` reports the new version:

```powershell
$dest = "$env:ProgramFiles\WindowsPowerShell\Modules\TU-ACME"
Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
if (Test-Path $dest) { Remove-Item -Path $dest -Recurse -Force }
Copy-Item -Path .\TU-ACME -Destination $dest -Recurse -Force
```

`Remove-Module` alone only unloads from the current session — the installed manifest on disk still has the old `ModuleVersion`. Also note that on PS 5.1, `Copy-Item -Recurse -Force` does **not** cleanly overwrite an existing module directory — it nests the source inside, leaving stale files. Always `Remove-Item` the destination first, then copy.

## Continuous Integration (GitHub Actions)
The project uses `.github/workflows/test.yml` to run automated tests on all branches and pull requests.

### Test Matrix Strategy
The workflow uses a **matrix strategy** to run test suites in parallel for efficiency:
- **Unit tests** — Core functionality and mocked dependencies
- **Integration tests** — Cross-module integration scenarios
- **Scripts tests** — Standalone script execution

All three test suites run **concurrently** on `windows-latest`, eliminating sequential job dependencies.

### Optimizations
- **Module Caching:** Dependencies (Pester, Posh-ACME) are cached between runs using `actions/cache@v4` to avoid repeated installations.
- **Reusable Steps:** Setup steps (checkout, version display, dependency installation, artifact publishing) are unified in a single job definition with matrix-driven tag filtering.
- **Smart Artifact Naming:** Test results are published with matrix-aware names (`test-results-Unit`, `test-results-Integration`, etc.) for easy identification.
- **Conditional Coverage:** Coverage reports are only generated for Unit tests (other matrices skip this step).

### Running Tests Locally
Before pushing, always run the full test suite locally:
```powershell
Invoke-Pester ./tests -Configuration (& .\tests\pester.config.ps1)
```
Or run a specific test type:
```powershell
$cfg = & .\tests\pester.config.ps1
$cfg.Filter.Tag = @('Unit')
Invoke-Pester -Configuration $cfg
```
