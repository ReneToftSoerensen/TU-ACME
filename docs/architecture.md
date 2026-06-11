# TU-ACME v2 — Architecture

## Key Principles

### Architecture

- **Two accounts owned by TU-ACME** — Created at first-run. No user-facing account picker.
- **Bootstrap functions only** — `Use-TUACMEProdAccount` and `Use-TUACMEStagingAccount` are the **only** callers of `Set-PAServer` and `Set-PAAccount` in the codebase.
- **Dry-run isolation** — Single, dedicated path that swaps to staging and restores prod in `try/finally`.
- **Small public surface** — New behavior = new private helper + menu entry, not new exported cmdlet.

## Platform & Requirements

- **OS:** Windows Server 2016+ or Windows 10/11.
- **PowerShell:** Windows PowerShell 5.1 **or** PowerShell 7.2+ on Windows (both runtimes first-class).
- **Dependencies:** Posh-ACME (PowerShell Gallery). No graphical libraries (console TUI only).
- **Privileges:** Admin for install, cert import, scheduled-task creation, IIS rebind. Background renewal runs as SYSTEM.

## Module Structure

```text
TU-ACME/
  TU-ACME/
    TU-ACME.psd1                      # Module manifest
    TU-ACME.psm1                      # Module entry
    Public/
      Start-TUACME.ps1                # Exported cmdlet
    Private/
      Bootstrap/
        Initialize-TUACMEEnvironment.ps1
        Use-TUACMEProdAccount.ps1
        Use-TUACMEStagingAccount.ps1
      Certificates/                   # Order, renew, revoke, dashboard
      UI/                             # Show-Menu and menu helpers
      Helpers/                        # Config, utilities
      Automation/                     # SMTP, scheduled tasks
    Scripts/
      Invoke-Renewal.ps1              # Background renewal script
  Usecases/
    UC-*.md                           # Atomic use cases (25 files)
  tests/
    Bootstrap.ps1
    pester.config.ps1
    Fixtures/
    UC-Traceability.md
    Unit/
    Integration/
    Scripts/
  SPEC.md
  ACCEPTANCE_CRITERIA.md
  README.md
  CLAUDE.md                           # This file (spec & framework root)
  AGENTS.md
  .claude/
    settings.json
    memory/
    skills/
    agents/
  .github/workflows/test.yml
```
