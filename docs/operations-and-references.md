# TU-ACME v2 — Operations and References

## Event ID Registry

TU-ACME logs to a custom Windows Event Log source. IDs are reserved in three bands:

| Band | Level | Purpose |
|------|-------|---------|
| 1000–1099 | Information | Normal operations (start, renewals, orders, bindings) |
| 2000–2999 | Warning | Recoverable issues (retried, degraded path) |
| 3000–3999 | Error | Unrecoverable failures |

**Reference:** See UC-8.01 and `ACCEPTANCE_CRITERIA.md` AC-F for the full list.

## Using This Framework

### For Developers

1. **Pick a use case** — See `README.md` for priority order.
2. **Read the UC file** — Understand requirements, test coverage.
3. **Write tests first** — Unit or Integration, depending on UC.
4. **Implement** — Make tests pass; follow code standards.
5. **Verify** — UTF-8 BOM, PS 5.1 compat, Pester suite.
6. **Commit** — Reference the UC(s) implemented.
7. **Update `README.md`** — Mark UC as done.

### For Code Reviewers

1. **Check traceability** — Does the change map to an AC in `ACCEPTANCE_CRITERIA.md`?
2. **Verify tests** — Are there passing tests? Do they cover the UC?
3. **Inspect standards** — UTF-8 BOM, PS 5.1 compat, no reimplementation, correct account bootstrap.
4. **Sign off on AC** — Is the acceptance criterion satisfied?

### For Operators

1. **See `SPEC.md`** — Project overview and architecture.
2. **See `README.md`** — Installation, first-run, basic workflows.
3. **See `Usecases/`** — Operational scenarios (UC-5 through UC-12).

## References

- **`SPEC.md`** — Full specification and design principles.
- **`ACCEPTANCE_CRITERIA.md`** — 39 ACs with traceability matrix.
- **`README.md`** — Overview, phasing, workflow, next steps.
- **`Usecases/`** — 25 atomic UC files (implementation guides).
- **`.claude/memory/`** — PS 5.1 and Posh-ACME pitfall notes.
- **`.claude/skills/`** — Project automation (`verify-utf8-bom`, `bump-version`, etc.).
- **`.claude/agents/`** — Specialized reviewers (`ps51-compat-linter`, `posh-acme-wrapper-reviewer`, `tui-pattern-checker`).

## Questions?

- **How do I check if a use case is complete?** → See `ACCEPTANCE_CRITERIA.md` traceability; all ACs for that UC must be marked done.
- **What if PS 5.1 and PS 7+ produce different results?** → Document the difference in the UC and decide via code review (usually, code to the PS 5.1 floor).
- **Can I use a PS 7 feature with a fallback?** → Only if the fallback works correctly on PS 5.1. Best practice: use PS 5.1 syntax everywhere.
- **How do I verify UTF-8 BOM?** → Use the `verify-utf8-bom` skill or check file bytes: first three should be `EF BB BF`.
- **What's the Event Log source name?** → `TU-ACME` (custom source registered during first-run via UC-1.02).
