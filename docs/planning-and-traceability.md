# TU-ACME v2 — Planning and Traceability

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
| **A. Module Initialization** | UC-1.01–02 | 4 | [x] |
| **B. Two-Account Model** | UC-2.01, 3.01 | 4 | [ ] |
| **C. TUI Menu** | UC-4.01–03 | 4 | [ ] |
| **D. Cert Operations** | UC-5–6 | 5 | [ ] |
| **E. Scheduled Renewal** | UC-7.01–02 | 3 | [ ] |
| **F. Event Logging** | UC-8.01 | 4 | [ ] |
| **G. IIS Integration** | UC-9.01–03 | 3 | [ ] |
| **H. Config & Persist** | UC-10.01–03 | 3 | [ ] |
| **I. Code Quality** | UC-11.01–05 | 5 | [ ] |
| **J. Ops Workflows** | UC-12.01–02 | 4 | [ ] |

See `ACCEPTANCE_CRITERIA.md` for the full traceability matrix.

## Development Checklist

- [x] **Phase 1** — Foundation (UC-1, 2, 11.01–03)
  - [x] UC-1.01 — Module import
  - [x] UC-1.02 — First-run wizard
  - [x] UC-2.01 — Account bootstrap
  - [x] UC-11.01–03 — UTF-8 BOM, PS 5.1 compat, unit tests
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
