# TU-ACME v2 — Overview

This documentation set contains the **specification-driven development framework** for TU-ACME v2: a Windows PowerShell 5.1 TUI wrapper around Posh-ACME targeting an internal corporate ACME certificate authority.

## Quick Start

1. **Read `SPEC.md`** — Project scope, design principles, platform requirements, architecture.
2. **Review `ACCEPTANCE_CRITERIA.md`** — 39 acceptance criteria across 10 feature areas (A–J); traceability matrix.
3. **Browse `Usecases/`** — atomic UC files; each contains narrative, acceptance criteria, implementation notes, and test coverage.
4. **Reference `README.md`** — Workflow guide, phasing (P0–P2), use case index, development checklist.

## Development Model

**Spec-driven development:** All acceptance criteria are written before code. Implementation follows the use cases. Every feature lands with passing tests.

### Workflow

1. **Choose a use case** from Phase 1 (P0 priority) — see `README.md`.
2. **Read the UC file** — Understand narrative, AC, implementation hints.
3. **Write failing tests first** — Unit test (mocked) or Integration test (real Posh-ACME store).
4. **Implement the feature** — Make the test pass; follow PS 5.1 compatibility rules.
5. **Verify UTF-8 BOM** — All `*.ps1`, `*.psm1`, `*.psd1` files must have BOM.
6. **Run full Pester suite** — Unit, Integration, and Scripts tags must pass.
7. **Commit with UC reference** — Example: `Implement UC-1.01 (module import)`.
8. **Mark UC as done** — Update checkbox in `README.md`.

## Locked Decisions

These decisions are inherited from the parent `CLAUDE.md` and locked for v2. Do not relitigate them in code review.

1. **Internal CA only** — Assumes a private corporate ACME directory. Server URLs and account IDs are non-sensitive.
2. **Two-account model** — Exactly one production and one staging account, created by TU-ACME at first-run.
3. **Plaintext config** — Server URLs and account IDs stored in `%ProgramData%\TU-ACME\config.json`.
4. **Prod is default** — All flows use production unless explicitly marked as dry-run.
5. **Dual-target runtime** — Windows PowerShell 5.1 **and** PowerShell 7.2+ on Windows. No PS7-only syntax.
6. **Posh-ACME is source of truth** — TU-ACME wraps; does not reimplement orders, accounts, or renewal logic.
7. **Fresh build** — Every file in v2 is new. Do not port v1 code wholesale.
