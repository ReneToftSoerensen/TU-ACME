# TU-ACME — Specification

## Project Overview

**TU-ACME** is a Windows PowerShell 5.1+ TUI wrapper around [Posh-ACME](https://github.com/rmbolger/Posh-ACME) targeting an internal corporate ACME certificate authority. It is **not** a general-purpose ACME client and is **not** designed for Let's Encrypt or any other public CA.

## Core Design Principles

1. **Internal CA only** — TU-ACME assumes a private corporate ACME directory.
2. **Two-account model** — exactly one production account and one staging account, created and managed by TU-ACME at first run.
3. **Plaintext configuration** — server URLs and account IDs stored in `%ProgramData%\TU-ACME\config.json`.
4. **Prod is default** — all flows run against production unless explicitly marked as dry-run.
5. **Dual-target runtime** — Windows PowerShell 5.1 **and** PowerShell 7+ on Windows (no PS7-only syntax).
6. **Posh-ACME as source of truth** — TU-ACME wraps; it does not reimplement orders, accounts, or renewal logic.

## Platform Requirements

- **OS:** Windows Server 2016+ or Windows 10/11
- **PowerShell:** Windows PowerShell 5.1 **or** PowerShell 7.2+ on Windows
- **Dependencies:** Posh-ACME (PowerShell Gallery)
- **Privileges:** Administrator for install, certificate import, scheduled-task creation, and IIS rebind

## Module Architecture

```
TU-ACME/
  TU-ACME.psd1                      # Module manifest
  TU-ACME.psm1                      # Module entry point
  Public/                           # Exported cmdlets
    Start-TUACME.ps1
  Private/
    Bootstrap/                      # Account/server initialization
    Certificates/                   # Order, renew, revoke, dashboard
    UI/                             # TUI menu system
    Helpers/                        # Configuration, utilities
    Automation/                     # SMTP, scheduled tasks
  Scripts/                          # Renewal task invoked by Scheduled Task
```

## Key Features (Minimal Viable Product)

### Phase 1: Foundation

- [ ] Module initialization and first-run configuration
- [ ] Two-account model (prod + staging) bootstrap
- [ ] Interactive TUI menu system (79-char titles, Cyan/DarkCyan chrome)
- [ ] Basic certificate order workflow
- [ ] Basic certificate renewal workflow
- [ ] Dry-run (staging) path

### Phase 2: Production Readiness

- [ ] Scheduled task installation for background renewal
- [ ] Windows Event Log integration (custom source, ID registry)
- [ ] IIS binding automation
- [ ] Certificate import to LocalMachine\My
- [ ] SMTP notifications

### Phase 3: Operations

- [ ] Certificate dashboard / status view
- [ ] Certificate revocation
- [ ] Force-renew with new key
- [ ] Configuration backup/restore

## Account Management

TU-ACME owns two accounts created at first run:

1. **Production Account** — used by default for all operations.
2. **Staging Account** — used only by explicit dry-run paths.

The account URLs and IDs are stored plaintext in `config.json` and are deliberately non-sensitive. All Posh-ACME calls route through `Use-TUACMEProdAccount` or `Use-TUACMEStagingAccount` bootstrap functions.

## Configuration Storage

| Item | Path | Format | Sensitivity |
|------|------|--------|-------------|
| Server URLs, account IDs, contact email | `%ProgramData%\TU-ACME\config.json` | Plaintext JSON | Non-sensitive |
| SMTP password, DNS credentials | Encrypted in `config.json` | DPAPI (per-machine) | Sensitive |
| Posh-ACME store | `%ProgramData%\Posh-ACME\` | Posh-ACME format | Mixed |

## Event Log Registry

TU-ACME logs to a custom Windows Event Log source using reserved ID bands:

| Band | Level | Purpose |
|------|-------|---------|
| 1000–1099 | Information | Normal operations (start, renewals, orders, bindings) |
| 2000–2999 | Warning | Recoverable issues |
| 3000–3999 | Error | Unrecoverable failures |

## Quality Standards

- **UTF-8 with BOM** on all `*.ps1`, `*.psm1`, `*.psd1` files.
- **Pester 5** test suite with Unit, Integration, and Scripts tags.
- **PS 5.1 compatibility** — no PS7-only syntax (`??`, `?.`, `?[`, `using namespace`, etc.).
- **No localization** — all code, comments, and identifiers in English.
- **Minimal comments** — explain WHY, not WHAT; trust well-named identifiers.

## Success Criteria

- Module loads and initializes cleanly on both PS 5.1 and PS 7+ (Windows).
- First-run wizard creates config and two accounts.
- TUI is responsive and navigable via keyboard.
- Certificate order, renewal, and revocation work end-to-end.
- Pester suite passes on CI (Unit, Integration, Scripts tags).
- No PS 5.1-incompatible syntax in the codebase.
- All PowerShell files have UTF-8 BOM.
