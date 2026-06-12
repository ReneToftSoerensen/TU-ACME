Plan one phase end-to-end before implementation starts. The phase number or name is: $ARGUMENTS. Stay in plan mode; do not write code.

## 1. Scope the phase

- Read `docs/planning-and-traceability.md` for the phase definition, its UC list, and priority. Cross-check `README.md` and `ACCEPTANCE_CRITERIA.md` for what earlier phases already ticked.
- List which UCs are candidates and which are explicitly out (later phases). Confirm the cut with the user via a question — phases have drifted before, and a wrong assumption here wastes the whole plan.

## 2. Read the spec, surface conflicts

- Read every in-scope `Usecases/UC-*.md` and its AC rows in `ACCEPTANCE_CRITERIA.md`.
- Check each against the locked decisions in `docs/overview.md` and the `implement-uc` skill. If two ACs contradict each other or a locked decision (it has happened: AC-A.1 "import never errors" vs the original AC-A.2 "wizard launches on import"), present the conflict and resolution options to the user as a decision — never silently pick one. Record the answer and note which spec files need their wording amended to match.

## 3. Write the plan

Cover, in order:

- **Files to create/change** — full paths, following the layout: one function per file under `TU-ACME/Private/<Area>/` or `TU-ACME/Public/`, mirrored tests under `tests/Unit/<Area>/`.
- **Function design** — signature, return type, and behavior per function; call out which existing helpers/bottlenecks each must go through (e.g. `Use-TUACME*Account` for server switches, `Write-TUACMEEventLog` for events, `Get/Save-TUACMEConfig` for config).
- **Test design** — per test file: what is mocked, key assertions, new fixtures or stubs needed in `tests/Fixtures/` (extend `PoshACME.Stubs.psm1` when wrapping new Posh-ACME commands). Everything mocked or `$TestDrive`; the Unit tier must stay under 10 s.
- **Quality gates** — anything new the phase needs in `tests/Unit/CodeQuality.Tests.ps1`, the pre-commit hook, or CI.
- **Implementation order** — test-first per UC, one commit per UC with the UC id; dependencies between UCs made explicit.
- **Verification** — concrete commands proving the phase done (suite green, smoke tests), plus what is deferred to integration tests or a manual Windows check.
- **Closeout** — spec amendments from step 2, AC boxes to tick, status updates in `README.md` and `docs/planning-and-traceability.md`.

## 4. Hand off

Present the plan for approval. Execution then follows the `implement-uc` skill per UC; new event ids go through `register-event-id`, version changes through `bump-version`.
