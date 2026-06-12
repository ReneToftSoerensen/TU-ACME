---
name: scaffold-greenfield-rewrite
description: Use when the user asks to "prepare a new greenfield project" / "clean rewrite in tiny usecases" / similar phrasing. Lays down a spec-driven scaffold in a target folder (default `clean/`) without copying v1 implementation code.
---

The user has asked for this three sessions in a row in the same shape. Default to the same shape unless they override.

## Target

- **Folder:** `clean/` at the repo root unless the user names a different one.
- **Branch:** stay on the current task branch; do not create a new branch unless asked.
- **Do not copy implementation files.** This is a spec-only scaffold — `TU-ACME/*.ps1` stays untouched.

## Layout to produce

```
clean/
  AGENTS.md             # DOX framework + project description
  CLAUDE.md             # spec-driven workflow, locked decisions inherited from root
  SPEC.md               # scope, design principles, platform, architecture
  ACCEPTANCE_CRITERIA.md  # AC list with traceability matrix
  README.md             # overview, phasing (P0/P1/P2), UC index, dev checklist
  Usecases/
    UC-<area>.<nn>-<slug>.md  # one file per atomic behavior
```

## Use case file shape

Each `UC-<d>.<nn>-<slug>.md` has:

1. **ID and title** — `UC-1.01 Module import`.
2. **Narrative** — one paragraph: who, what, why.
3. **Acceptance criteria** — Given/When/Then bullets, one criterion per bullet, each tagged with its AC ID from `ACCEPTANCE_CRITERIA.md`.
4. **Implementation notes** — pointers to private helpers, Posh-ACME cmdlets, config keys; do not write code.
5. **Test coverage** — which Pester tier (`Unit` / `Integration` / `Scripts`) and the test file path.

## Seeding rules

- Copy the **locked decisions** verbatim from root `CLAUDE.md` into `clean/CLAUDE.md`. Do not re-litigate them.
- Seed `Usecases/` from the existing top-level `Usecases/` as the starting set, then prompt the user for additions. HTTP-01 variants (self-host + webroot) and IIS auto-rebind have come up every time — surface those as candidates.
- Phase the UCs into P0 (foundation: module import, account bootstrap, UTF-8/PS5.1 baseline), P1 (production: TUI, order, renew, schedule, event log, IIS, config), P2 (operations: revoke, force-renew, dashboard advanced).
- Update `clean/AGENTS.md` with the project one-liner and a Child DOX Index pointing at SPEC / ACCEPTANCE_CRITERIA / README / Usecases.

## Do not

- Port v1 code into `clean/`. The wipe-and-rebuild rule from root `CLAUDE.md` still applies.
- Add CI yaml, deployment scripts, or `.claude/` config under `clean/` — those stay at the repo root.
- Create the scaffold silently. After laying it down, list the UC index back to the user and ask which P0 item to start on.
