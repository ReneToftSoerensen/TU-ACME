# TU-ACME v2 — Planning and Traceability

## Acceptance Criteria Mapping

### Phases

| Phase | Priority | UCs | Focus |
|-------|----------|-----|-------|
| **Foundation (P0)** | Must Have | UC-1.01–1.02, 2.01, 11.01–03 | Module, accounts, tests, UTF-8/compat |
| **Production (P1)** | Should Have | UC-3.01, 4.01–03, 5.01–02, 6.01, 7.01–02, 8.01, 9.01, 10.01–03, 11.04–05, 12.01 | Dry-run, menu, orders, renewal, ops |
| **Operations (P2)** | Nice to Have | UC-6.02–03, 9.02–03, 12.02 (J.4) | Revoke, force-renew, IIS rebind/recovery, advanced ops |

### Feature Areas

| Area | UCs | ACs | Status |
|------|-----|-----|--------|
| **A. Module Initialization** | UC-1.01–02 | 4 | [x] |
| **B. Two-Account Model** | UC-2.01, 3.01 | 4 | [x] |
| **C. TUI Menu** | UC-4.01–03, 5.04 (multi-select) | 5 | [x] |
| **D. Cert Operations** | UC-5–6, 5.04 | 6 | [x] |
| **E. Scheduled Renewal** | UC-7.01–02 | 3 | [x] |
| **F. Event Logging** | UC-8.01 | 4 | [x] |
| **G. IIS Integration** | UC-9.01–03 | 3 | [x] |
| **H. Config & Persist** | UC-10.01–03 | 3 | [x] |
| **I. Code Quality** | UC-11.01–05 | 5 | [x] |
| **J. Ops Workflows** | UC-12.01–02 | 4 | [x] |

See `ACCEPTANCE_CRITERIA.md` for the full traceability matrix.

## Development Checklist

- [x] **Phase 1** — Foundation (UC-1, 2, 11.01–03)
  - [x] UC-1.01 — Module import
  - [x] UC-1.02 — First-run wizard
  - [x] UC-2.01 — Account bootstrap
  - [x] UC-11.01–03 — UTF-8 BOM, PS 5.1 compat, unit tests
- [x] **Phase 2** — Production (UC-3.01, 4–8, 9.01, 10–11, 12.01)
  - [x] UC-3.01 — Dry-run
  - [x] UC-4.01–03 — TUI menu
  - [x] UC-5.01–02 — Cert ordering
  - [x] UC-6.01 — Renew
  - [x] UC-7.01–02 — Scheduled task & script
  - [x] UC-8.01 — Event logging
  - [x] UC-9.01 — IIS discovery
  - [x] UC-10.01–03 — Config & encryption
  - [x] UC-11.04–05 — Integration & script tests
  - [x] UC-12.01 — Dashboard
- [x] **Phase 3** — Operations (UC-6.02–03, 9.02–03, 12.02)
  - [x] UC-6.02 — Revoke
  - [x] UC-6.03 — Force-renew
  - [x] UC-9.02 — IIS rebind
  - [x] UC-9.03 — IIS rebind failure recovery
  - [x] UC-12.02 — Renewal status (advanced)
- [x] **Phase 4** — UX Enhancements
  - [x] UC-5.04 — Quick-select known names (FQDN / hostname / IIS host headers) as CN/SAN (AC-C.5, AC-D.6)
- [ ] **Verification**
  - [ ] All tests pass (Unit, Integration, Scripts) — validate on CI
  - [ ] PS 5.1 and PS 7+ both green on CI
  - [x] All `.ps1`, `.psm1`, `.psd1` files have UTF-8 BOM
  - [x] No PS7-only syntax in codebase
  - [ ] Installation and first-run tested on clean Windows VM
