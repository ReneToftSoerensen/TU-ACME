---
name: implement-uc
description: Use when the user asks to implement a use case or phase ("implement UC-3.01", "do Phase 2"). Runs the spec-driven pipeline from UC file to ticked traceability boxes.
---

Implement one UC at a time through this pipeline:

1. **Read the spec**: `Usecases/UC-<id>-*.md` and the matching AC rows in `ACCEPTANCE_CRITERIA.md`. If the UC conflicts with a locked decision (below), surface it before coding.
2. **Write failing tests first** in `tests/Unit/` (Pester 5, `Describe -Tag 'Unit'`). Conventions: dot-source `tests/Bootstrap.ps1` in `BeforeAll`; mock with `Mock -ModuleName 'TU-ACME'` and call private functions via `InModuleScope 'TU-ACME'`; isolate config with `$env:TUACME_DATA_DIR = Join-Path $TestDrive ...` in `BeforeEach`; Posh-ACME commands resolve via `tests/Fixtures/PoshACME.Stubs.psm1` (each throws unless mocked) — never require real Posh-ACME in unit tests.
3. **Implement** in `TU-ACME/Private/<Area>/` or `TU-ACME/Public/` (one function per file, file named after the function). Public cmdlets must also be added to `FunctionsToExport` in the manifest and `Export-ModuleMember` in the psm1.
4. **Quality gates**: PS 5.1-safe syntax only (no `??`, `?.`, ternary, pipeline chains, `-AsHashtable`, `-Parallel`); UTF-8 BOM on every new/edited `.ps1/.psm1/.psd1` (run the `fix-bom` skill); run the suite via the `run-pester` skill — must stay green and under 10 s.
5. **Traceability closeout**: tick the AC checkboxes in `ACCEPTANCE_CRITERIA.md`, update status in `README.md` and `docs/planning-and-traceability.md`.
6. **Commit per UC** with the UC id in the message.

Locked decisions (do not re-litigate):
- TU-ACME wraps Posh-ACME, never reimplements ACME logic.
- Only `Use-TUACMEProdAccount`/`Use-TUACMEStagingAccount` may call `Set-PAServer`/`Set-PAAccount` (AST-enforced by `tests/Unit/CodeQuality.Tests.ps1`).
- The first-run wizard launches only from `Start-TUACME`; module import never prompts and never errors (AC-A.1) — failures downgrade to warnings.
- Posh-ACME stays out of `RequiredModules` so import and unit tests work without it.
- Event Log writes go through `Write-TUACMEEventLog` (never throws); register new event ids via the `register-event-id` skill.
