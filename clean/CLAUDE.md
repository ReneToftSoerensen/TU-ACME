# TU-ACME v2 — Clean Implementation CLAUDE.md

This folder contains the **specification-driven development framework** for TU-ACME v2: a Windows PowerShell 5.1 TUI wrapper around Posh-ACME targeting an internal corporate ACME certificate authority.

## Quick Start

1. **Read SPEC.md** — Project scope, design principles, platform requirements, architecture.
2. **Review ACCEPTANCE_CRITERIA.md** — 39 acceptance criteria across 10 feature areas (A–J); traceability matrix.
3. **Browse Usecases/** — 25 atomic UC files; each contains narrative, acceptance criteria, implementation notes, and test coverage.
4. **Reference README.md** — Workflow guide, phasing (P0–P2), use case index, development checklist.

## Development Model

**Spec-driven development:** All acceptance criteria are written before code. Implementation follows the usecases. Every feature lands with passing tests.

### Workflow

1. **Choose a usecase** from Phase 1 (P0 priority) — see README.md.
2. **Read the UC file** — Understand narrative, AC, implementation hints.
3. **Write failing tests first** — Unit test (mocked) or Integration test (real Posh-ACME store).
4. **Implement the feature** — Make the test pass; follow PS 5.1 compat rules.
5. **Verify UTF-8 BOM** — All `*.ps1`, `*.psm1`, `*.psd1` files must have BOM.
6. **Run full Pester suite** — Unit, Integration, and Scripts tags must pass.
7. **Commit with UC reference** — E.g., "Implement UC-1.01 (module import)".
8. **Mark UC as done** — Update checkbox in README.md.

## Locked Decisions

These decisions are inherited from the parent CLAUDE.md and locked for v2. Do not relitigate them in code review.

1. **Internal CA only** — Assumes a private corporate ACME directory. Server URLs and account IDs are non-sensitive.
2. **Two-account model** — Exactly one production and one staging account, created by TU-ACME at first-run.
3. **Plaintext config** — Server URLs and account IDs stored in `%ProgramData%\TU-ACME\config.json`.
4. **Prod is default** — All flows use production unless explicitly marked as dry-run.
5. **Dual-target runtime** — Windows PowerShell 5.1 **and** PowerShell 7.2+ on Windows. No PS7-only syntax.
6. **Posh-ACME is source of truth** — TU-ACME wraps; does not reimplement orders, accounts, or renewal logic.
7. **Fresh build** — Every file in v2 is new. Do not port v1 code wholesale.

## Key Principles

### Architecture

- **Two accounts owned by TU-ACME** — Created at first-run. No user-facing account picker.
- **Bootstrap functions only** — `Use-TUACMEProdAccount` and `Use-TUACMEStagingAccount` are the **only** callers of `Set-PAServer` and `Set-PAAccount` in the codebase.
- **Dry-run isolation** — Single, dedicated path that swaps to staging and restores prod in `try/finally`.
- **Small public surface** — New behavior = new private helper + menu entry, not new exported cmdlet.

### Code Quality

- **UTF-8 with BOM** — All `*.ps1`, `*.psm1`, `*.psd1` files (Windows PowerShell 5.1 requirement).
- **PS 5.1 compatible** — No `??`, `?.`, `?[`, ternary `a ? b : c`, `using namespace`, `ConvertFrom-Json -AsHashtable`, `ForEach-Object -Parallel`, etc.
- **English only** — All identifiers, comments, commit messages, and documentation in English.
- **Minimal comments** — Explain WHY, not WHAT. Trust well-named identifiers.
- **No pre-emptive abstractions** — Three similar lines is OK; don't abstract until needed.

### Security

- **Read-Host -AsSecureString** for SMTP password and DNS credentials only.
- **DPAPI encryption** (per-machine, no key) for credentials stored in config.json.
- **Plaintext URLs and account IDs** — Deliberate and non-sensitive; do not encrypt.
- **No credential logging** — Log presence and result only; never log credential bodies.

## Platform & Requirements

- **OS:** Windows Server 2016+ or Windows 10/11.
- **PowerShell:** Windows PowerShell 5.1 **or** PowerShell 7.2+ on Windows (both runtimes first-class).
- **Dependencies:** Posh-ACME (PowerShell Gallery). No graphical libraries (console TUI only).
- **Privileges:** Admin for install, cert import, scheduled-task creation, IIS rebind. Background renewal runs as SYSTEM.

## Module Structure

```
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
  clean/                              # This folder (spec & framework)
    SPEC.md
    ACCEPTANCE_CRITERIA.md
    README.md
    CLAUDE.md (this file)
  .claude/
    settings.json
    memory/
    skills/
    agents/
  .github/workflows/test.yml
  CLAUDE.md (root)
```

## Acceptance Criteria Mapping

### Phases

| Phase | Priority | UCs | Focus |
|-------|----------|-----|-------|
| **Foundation (P0)** | Must Have | UC-1.01–1.02, 2.01, 11.01–03 | Module, accounts, tests, UTF-8/compat |
| **Production (P1)** | Should Have | UC-3.01, 4.01–03, 5.01–02, 6.01, 7–12 | Dry-run, menu, orders, renewal, ops |
| **Operations (P2)** | Nice to Have | UC-6.02–03, J.4 | Revoke, force-renew, advanced ops |

### Feature Areas

| Area | UCs | ACs | Status |
|------|-----|-----|--------|
| **A. Module Initialization** | UC-1.01–02 | 4 | [ ] |
| **B. Two-Account Model** | UC-2.01, 3.01 | 4 | [ ] |
| **C. TUI Menu** | UC-4.01–03 | 4 | [ ] |
| **D. Cert Operations** | UC-5–6 | 5 | [ ] |
| **E. Scheduled Renewal** | UC-7.01–02 | 3 | [ ] |
| **F. Event Logging** | UC-8.01 | 4 | [ ] |
| **G. IIS Integration** | UC-9.01–03 | 3 | [ ] |
| **H. Config & Persist** | UC-10.01–03 | 3 | [ ] |
| **I. Code Quality** | UC-11.01–05 | 5 | [ ] |
| **J. Ops Workflows** | UC-12.01–02 | 4 | [ ] |

See ACCEPTANCE_CRITERIA.md for full traceability matrix.

## Event ID Registry

TU-ACME logs to a custom Windows Event Log source. IDs are reserved in three bands:

| Band | Level | Purpose |
|------|-------|---------|
| 1000–1099 | Information | Normal operations (start, renewals, orders, bindings) |
| 2000–2999 | Warning | Recoverable issues (retried, degraded path) |
| 3000–3999 | Error | Unrecoverable failures |

**Reference:** See UC-8.01 and ACCEPTANCE_CRITERIA.md AC-F for full list.

## TUI Standards

- **Menu titles** — ≤79 characters (enforced).
- **Colors** — Cyan and DarkCyan only (no Red, Green, Yellow, etc.).
- **Navigation** — Arrow keys (up/down), Enter to select, `/` to search.
- **Disabled items** — Tracked via `DisabledIndices` array; skipped during navigation.
- **Search** — Case-insensitive, filters matching items.

See UC-4.01–4.03 for detailed specifications.

## Testing Strategy

**Three-tier Pester suite:**

1. **Unit** (`-Tag Unit`) — Mocked Posh-ACME and file I/O. Pure function testing.
2. **Integration** (`-Tag Integration`) — Real Posh-ACME store on disk. Wiring and data flow.
3. **Scripts** (`-Tag Scripts`) — Fake objects, renewal and deployment scripts end-to-end.

**Each UC includes test coverage guidance.** Every new feature lands with tests.

## Development Checklist

- [ ] **Phase 1** — Foundation (UC-1, 2, 11.01–03)
  - [ ] UC-1.01 — Module import
  - [ ] UC-1.02 — First-run wizard
  - [ ] UC-2.01 — Account bootstrap
  - [ ] UC-11.01–03 — UTF-8 BOM, PS 5.1 compat, unit tests
- [ ] **Phase 2** — Production (UC-3–12)
  - [ ] UC-3.01 — Dry-run
  - [ ] UC-4.01–03 — TUI menu
  - [ ] UC-5.01–02 — Cert ordering
  - [ ] UC-6.01 — Renew
  - [ ] UC-7.01–02 — Scheduled task & script
  - [ ] UC-8.01 — Event logging
  - [ ] UC-9.01–03 — IIS
  - [ ] UC-10.01–03 — Config & encryption
  - [ ] UC-11.04–05 — Integration & script tests
  - [ ] UC-12.01–02 — Dashboard & status
- [ ] **Phase 3** — Operations (UC-6.02–03, J.4)
  - [ ] UC-6.02 — Revoke
  - [ ] UC-6.03 — Force-renew
  - [ ] UC-12.02 — Renewal status (advanced)
- [ ] **Verification**
  - [ ] All tests pass (Unit, Integration, Scripts)
  - [ ] PS 5.1 and PS 7+ both green on CI
  - [ ] All `.ps1`, `.psm1`, `.psd1` files have UTF-8 BOM
  - [ ] No PS7-only syntax in codebase
  - [ ] Installation and first-run tested on clean Windows VM

## Using This Framework

### For Developers

1. **Pick a usecase** — See README.md for priority order.
2. **Read the UC file** — Understand requirements, test coverage.
3. **Write tests first** — Unit or Integration, depending on UC.
4. **Implement** — Make tests pass; follow code standards.
5. **Verify** — UTF-8 BOM, PS 5.1 compat, Pester suite.
6. **Commit** — Reference the UC(s) implemented.
7. **Update README.md** — Mark UC as done.

### For Code Reviewers

1. **Check traceability** — Does the change map to an AC in ACCEPTANCE_CRITERIA.md?
2. **Verify tests** — Are there passing tests? Do they cover the UC?
3. **Inspect standards** — UTF-8 BOM, PS 5.1 compat, no reimplementation, correct account bootstrap.
4. **Sign off on AC** — Is the acceptance criterion satisfied?

### For Operators

1. **See SPEC.md** — Project overview and architecture.
2. **See README.md** — Installation, first-run, basic workflows.
3. **See Usecases/** — Operational scenarios (UC-5 through UC-12).

## References

- **SPEC.md** — Full specification and design principles.
- **ACCEPTANCE_CRITERIA.md** — 39 ACs with traceability matrix.
- **README.md** — Overview, phasing, workflow, next steps.
- **Usecases/** — 25 atomic UC files (implementation guides).
- **../CLAUDE.md** — Root project standards (inherited).
- **.claude/memory/** — PS 5.1 and Posh-ACME pitfall notes.
- **.claude/skills/** — Project automation (verify-utf8-bom, bump-version, etc.).
- **.claude/agents/** — Specialized reviewers (ps51-compat-linter, posh-acme-wrapper-reviewer, tui-pattern-checker).

## Questions?

- **How do I check if a usecase is complete?** → See ACCEPTANCE_CRITERIA.md traceability; all ACs for that UC must be marked done.
- **What if PS 5.1 and PS 7+ produce different results?** → Document the difference in the UC and decide via code review (usually, code to PS 5.1 floor).
- **Can I use a PS 7 feature with a fallback?** → Only if the fallback works correctly on PS 5.1. Best practice: use PS 5.1 syntax everywhere.
- **How do I verify UTF-8 BOM?** → Use the `verify-utf8-bom` skill or check file bytes: first three should be `EF BB BF`.
- **What's the Event Log source name?** → `TU-ACME` (custom source registered during first-run via UC-1.02).
