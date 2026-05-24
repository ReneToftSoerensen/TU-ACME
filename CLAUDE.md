# TU-ACME

A Windows PowerShell 5.1 TUI wrapper around [Posh-ACME](https://github.com/rmbolger/Posh-ACME) targeting an **internal corporate ACME certificate authority**. TU-ACME is not a general-purpose ACME client and is not designed for Let's Encrypt or any other public CA. The module owns its prod and staging accounts end-to-end so operators never select an account or server by hand.

## Locked decisions

The following decisions are locked for v2. Do not relitigate them in code review.

1. **Internal CA only.** TU-ACME assumes a private corporate ACME directory. Server URLs and account IDs are deliberately treated as non-sensitive operational config.
2. **Two-account model owned by TU-ACME.** The module creates and manages exactly one production account and one staging account at first run. There is no Accounts menu and no user-facing account picker.
3. **Plaintext server URLs and account IDs** are stored in `%ProgramData%\TU-ACME\config.json`. Encryption is reserved for genuine secrets (SMTP password, DNS plugin credentials).
4. **Prod is the default; Dry-run uses staging.** Every flow that doesn't explicitly mark itself as a dry-run runs against the production account. Dry-run is the single, dedicated path that swaps to staging and swaps back.
5. **Windows PowerShell 5.1, UTF-8 BOM on every script.** The module targets `$PSVersionTable.PSVersion.Major -eq 5`. No PS7-only syntax.
6. **Posh-ACME is the source of truth.** TU-ACME wraps; it does not reimplement orders, accounts, or renewal logic.
7. **The repo was wiped and rebuilt.** v1 history is still in git for reference, but every file in v2 is new. Do not port v1 code wholesale without a deliberate decision.

## Platform and minimum requirements

- **OS:** Windows Server 2016+ or Windows 10/11.
- **PowerShell:** Windows PowerShell 5.1. PS 7 is not a supported runtime.
- **Dependencies:** Posh-ACME (PowerShell Gallery). No graphical libraries; the UI is a console TUI.
- **Privileges:** Administrator for install, certificate-store import, scheduled-task creation, and IIS rebind. Background renewal runs as SYSTEM.

## Folder structure

```
TU-ACME/
  TU-ACME/                 # PowerShell module (owned by the module agent)
    TU-ACME.psd1
    TU-ACME.psm1
    Public/                # Exported cmdlets (Start-TUACME, etc.)
    Private/
      Bootstrap/           # Initialize-TUACMEEnvironment, Use-TUACMEProdAccount, Use-TUACMEStagingAccount
      Certificates/        # Order, renew, revoke, dashboard helpers
      UI/                  # Show-Menu and menu helpers
      Helpers/             # Get-TUACMEConfig and other small utilities
      Automation/          # Invoke-SMTPConfig, scheduled task install
    Scripts/               # Renewal script invoked by the scheduled task
  Usecases/                # Atomic UC-<d>.<nn>-<slug>.md files
  tests/
    Bootstrap.ps1
    pester.config.ps1
    Fixtures/FakeObjects.ps1
    UC-Traceability.md
    Unit/
    Integration/
    Scripts/
  .claude/
    settings.json
    memory/                # Posh-ACME and PS 5.1 pitfall notes
    skills/                # Project-specific skills
    agents/                # Reviewer agents
  .github/workflows/test.yml
  CLAUDE.md
  README.md
  INSTALL.md
  SMOKE-TEST.md
  LICENSE
  deploy.ps1
  .gitignore
```

## Technical stack

| Concern | Choice |
|---|---|
| Runtime | Windows PowerShell 5.1 |
| TUI engine | Custom `Show-Menu` over the host console (Cyan/DarkCyan chrome) |
| Distribution | PowerShell module copied via `deploy.ps1` |
| Install path | `$env:ProgramFiles\WindowsPowerShell\Modules\TU-ACME\` |
| Configuration path | `%ProgramData%\TU-ACME\config.json` (plaintext URLs, account IDs, contact email) |
| Posh-ACME store path | `%ProgramData%\Posh-ACME\` (shared between admin and SYSTEM) |
| Secret encryption | DPAPI (per-machine) for SMTP password and DNS plugin credentials only |
| Logging | Windows Event Log, custom source, IDs in registry below |

## Architecture principles

- **TU-ACME owns two accounts (prod + staging) created at first-run. Never prompt the user to pick an account or server. Always go through `Use-TUACMEProdAccount` / `Use-TUACMEStagingAccount`.** Direct calls to `Set-PAServer` or `Set-PAAccount` outside `Private/Bootstrap/` are forbidden.
- Public surface is small. New behavior generally means a new private helper plus a new menu entry, not a new exported cmdlet.
- Every TUI flow that performs a certificate operation calls one of the two `Use-TUACME*Account` helpers at the top before any `Posh-ACME` cmdlet runs.
- Dry-run is the one and only path that selects staging. It wraps the operation in a `try/finally` that restores prod.

## Account / server module

Lives under `TU-ACME/Private/Bootstrap/`.

- **`Initialize-TUACMEEnvironment`** — run on module import. Ensures `%ProgramData%\TU-ACME\` exists, redirects `POSHACME_HOME` to `%ProgramData%\Posh-ACME\` so admin and SYSTEM see the same store, and triggers the first-run wizard if `config.json` is absent.
- **`Use-TUACMEProdAccount`** — calls `Set-PAServer <prod-url>` then `Set-PAAccount <prod-account-id>`. Returns the previously active server URL so callers can restore it if they need to.
- **`Use-TUACMEStagingAccount`** — same shape, points at staging. Always paired with a `try/finally` that calls `Use-TUACMEProdAccount` at the end.

These three functions are the only callers of `Set-PAServer` / `Set-PAAccount` in the entire codebase.

## Event ID registry

TU-ACME writes to a custom Windows Event Log source. Reserve IDs in three bands:

| ID | Level | Meaning |
|---|---|---|
| 1010 | Information | Module initialization / first-run wizard completed |
| 1001 | Information | Scheduled renewal run |
| 1002 | Information | IIS binding refreshed with new thumbprint |
| 1004 | Information | Certificate revoked |
| 1005 | Information | Force-renew with new key requested |
| 2xxx | Warning | Recoverable issue (degraded path, retry succeeded) |
| 3xxx | Error | Unrecoverable failure surfaced to the operator |

When adding a new event source, use the next free ID in the appropriate band and update this table via the `register-event-id` skill.

## Skills and Agents

Project-specific automation lives under `.claude/`. Each entry is invoked through the standard Skill / Agent mechanism.

**Skills** (`.claude/skills/`):
- `add-use-case` — scaffold a new atomic UC and update the traceability matrix.
- `bump-version` — update every version literal in lockstep.
- `run-pester` — run the Pester 5 suite with `pester.config.ps1`.
- `new-private-function` — scaffold a private `.ps1` and its empty Pester file.
- `verify-utf8-bom` — walk every PowerShell file and report missing BOMs.
- `register-event-id` — reserve the next free event ID and update the registry table above.
- `posh-acme-expert` — Posh-ACME pitfall knowledge ported from v1.
- `powershell-5.1-expert` — PS 5.1 idioms and limitations ported from v1.

**Agents** (`.claude/agents/`):
- `posh-acme-wrapper-reviewer` — fires on diffs in `Certificates/`, `Bootstrap/`, or `Scripts/`; flags Posh-ACME reimplementation and stray `Set-PA*` calls.
- `tui-pattern-checker` — fires on diffs in `Private/UI/` or `Invoke-*Menu.ps1`; enforces `Show-Menu`, 79-char titles, color discipline, `DisabledIndices`, and `/` search.
- `ps51-compat-linter` — fires pre-commit on any `*.ps1` diff; catches PS7-only syntax and missing UTF-8 BOMs.

## Security guidelines

- Use `Read-Host -AsSecureString` only for the SMTP password and DNS-plugin credentials. Store the resulting `SecureString` via DPAPI (`ConvertFrom-SecureString` without a key, per-machine).
- Server URLs and account IDs are deliberately plaintext in `config.json`. Do not "harden" this by adding encryption — it would only make ops worse without raising any security bar against the threat model.
- Do not log credential bodies. Log only their presence and the result of using them.

## File encoding

All `*.ps1`, `*.psm1`, and `*.psd1` files **must** be UTF-8 with BOM (first three bytes `EF BB BF`). Windows PowerShell 5.1's default parser expects this for non-ASCII characters and for consistent behavior under the ISE. The `verify-utf8-bom` skill and the `ps51-compat-linter` agent both check this on every diff. Markdown files do not need a BOM.

## Language

All code, comments, identifiers, commit messages, and documentation are in **English**. No mixed-language strings, no localized resource files.

## Development workflow

1. Make the change.
2. Run the Pester suite via the `run-pester` skill. Every change should land with a passing run; new behavior should land with new tests.
3. Verify UTF-8 BOM on every touched PowerShell file via the `verify-utf8-bom` skill.
4. If the change is user-visible (menu text, prompts, certificate behavior), bump the version via the `bump-version` skill before committing.
5. Commit with a one-line summary that mentions the version bump if one happened.

## Versioning

A version bump must update every literal below in the same commit. The `bump-version` skill automates this — use it.

| File | Where |
|---|---|
| `TU-ACME/TU-ACME.psd1` | `ModuleVersion = '<new>'` |
| `TU-ACME/Private/Helpers/Get-TUACMEConfig.ps1` | `Version = '<new>'` in `$defaults` |
| `TU-ACME/Public/Start-TUACME.ps1` | title literal |
| `TU-ACME/Private/Automation/Invoke-SMTPConfig.ps1` | test-mail body |
| `README.md`, `INSTALL.md`, `SMOKE-TEST.md` | usage/verify/banner lines |

All 0.x releases are pre-production.

## CI

`.github/workflows/test.yml` runs the Pester suite on `windows-latest` across three tiers in parallel:

- **Unit** — pure module functions with mocked Posh-ACME (`-Tag Unit`, excludes `Integration` and `LiveExternal`).
- **Integration** — exercises module wiring against a real Posh-ACME store on disk (`-Tag Integration`, still excludes `LiveExternal`).
- **Scripts** — exercises the renewal and deploy scripts end-to-end against fake objects (`-Tag Scripts`).

The `LiveExternal` tag is reserved for tests that hit the real internal CA and is excluded from CI by default; run those locally before tagging a release.
