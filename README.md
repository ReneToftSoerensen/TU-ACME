# TU-ACME v2 — Clean Implementation

This folder contains the specification, acceptance criteria, and atomic use cases for a clean, spec-driven implementation of TU-ACME v2.

## Structure

- **SPEC.md** — High-level project specification, design principles, and requirements.
- **ACCEPTANCE_CRITERIA.md** — Detailed acceptance criteria organized by feature area (A–J).
- **Usecases/** — Atomic use case files (UC-*.md), one per feature or workflow.

## Workflow

1. **Read SPEC.md** — Understand the project scope and architecture.
2. **Review ACCEPTANCE_CRITERIA.md** — See the full matrix of what must be delivered.
3. **Work through Usecases/** — Each UC file contains:
   - Narrative (user story)
   - Acceptance criteria (specific, testable)
   - Implementation notes (hints and patterns)
   - Test coverage guidance (Unit, Integration, Scripts)

## Key Principles

- **Spec-driven development** — All acceptance criteria are written first; code is written to pass.
- **Atomic use cases** — Each UC is small, independent, and testable.
- **Traceability** — Every acceptance criterion is linked to one or more UCs.
- **Posh-ACME first** — TU-ACME wraps, never reimplements.
- **Windows PowerShell 5.1 + PS 7+** — Dual-target, no PS7-only syntax.
- **UTF-8 BOM on all .ps1/.psm1/.psd1 files** — Mandatory for PS 5.1 parsing.

## Phasing

### Phase 1: Foundation (P0 — Must Have)

- Module import and first-run initialization
- Two-account model (prod + staging)
- Account bootstrap functions
- Basic certificate order (prod + dry-run)
- Scheduled task infrastructure
- Event logging framework
- Pester test framework (Unit, Integration, Scripts)

### Phase 2: Production Readiness (P1 — Should Have)

- Renewal (manual + scheduled)
- IIS binding automation (discover, rebind, recovery)
- Certificate dashboard and renewal status
- TUI menu system (navigation, search, colors)
- Dry-run isolation
- Configuration persistence and encryption
- SMTP notifications (optional)

### Phase 3: Operations (P2 — Nice to Have)

- Certificate revocation
- Force-renew with new key
- DNS plugin support
- Configuration backup/restore
- Advanced IIS scenarios

## Acceptance Criteria Matrix

| Area | Count | Priority | Status |
|------|-------|----------|--------|
| A. Module Initialization | 4 | P0 | [ ] |
| B. Two-Account Model | 4 | P0–P1 | [ ] |
| C. TUI Menu System | 4 | P1 | [ ] |
| D. Certificate Operations | 5 | P0–P2 | [ ] |
| E. Scheduled Renewal | 3 | P1 | [ ] |
| F. Event Logging | 4 | P1 | [ ] |
| G. IIS Integration | 3 | P1 | [ ] |
| H. Config & Persistence | 3 | P0–P1 | [ ] |
| I. Code Quality | 5 | P0 | [ ] |
| J. Operational Workflows | 4 | P1 | [ ] |
| **Total** | **39** | — | — |

## Use Case Index

### Phase 1: Foundation

| UC | Title | Status |
|----|-------|--------|
| UC-1.01 | Module Import | [ ] |
| UC-1.02 | First-Run Wizard | [ ] |
| UC-2.01 | Account Bootstrap | [ ] |
| UC-3.01 | Dry-Run | [ ] |
| UC-11.01 | UTF-8 BOM | [ ] |
| UC-11.02 | PS 5.1 Compatibility | [ ] |
| UC-11.03 | Unit Tests | [ ] |

### Phase 2: Production Readiness

| UC | Title | Status |
|----|-------|--------|
| UC-4.01 | Menu Navigation | [ ] |
| UC-4.02 | Menu Search | [ ] |
| UC-4.03 | Menu Format | [ ] |
| UC-5.01 | Order Certificate (Prod) | [ ] |
| UC-5.02 | Order Certificate (Dry-Run) | [ ] |
| UC-6.01 | Renew Certificate | [ ] |
| UC-7.01 | Scheduled Task | [ ] |
| UC-7.02 | Renewal Script | [ ] |
| UC-8.01 | Event Logging | [ ] |
| UC-9.01 | IIS Discovery | [ ] |
| UC-9.02 | IIS Rebind | [ ] |
| UC-9.03 | IIS Recovery | [ ] |
| UC-10.01 | Config Persistence | [ ] |
| UC-10.02 | SMTP Encryption | [ ] |
| UC-10.03 | DNS Encryption | [ ] |
| UC-11.04 | Integration Tests | [ ] |
| UC-11.05 | Script Tests | [ ] |
| UC-12.01 | Dashboard | [ ] |
| UC-12.02 | Renewal Status | [ ] |

### Phase 3: Operations

| UC | Title | Status |
|----|-------|--------|
| UC-6.02 | Revoke Certificate | [ ] |
| UC-6.03 | Force-Renew with New Key | [ ] |
| UC-J.4 | Renewal Status (menu) | [ ] |

## Development Checklist

- [ ] **Plan** — Review SPEC and AC matrix; prioritize Phase 1 usecases.
- [ ] **Bootstrap** — Create module structure, first-run wizard, account functions.
- [ ] **Test** — Write Pester tests (Unit) alongside implementation.
- [ ] **Integrate** — Add file I/O, event logging, config persistence.
- [ ] **Polish** — TUI menu, colors, search; verify PS 5.1 + PS 7+.
- [ ] **Verify** — Run full Pester suite; all tests green.
- [ ] **Deploy** — Test installation and first-run on clean Windows VM.

## Resources

- **SPEC.md** — Project specification and architecture
- **ACCEPTANCE_CRITERIA.md** — Detailed AC matrix with traceability
- **Usecases/UC-*.md** — Individual use case files (implementation guides)
- **.claude/memory/** — PS 5.1 and Posh-ACME pitfall notes
- **.claude/skills/** — Project-specific skills (verify-utf8-bom, bump-version, etc.)
- **.claude/agents/** — Specialized reviewers (ps51-compat-linter, posh-acme-wrapper-reviewer, tui-pattern-checker)

## Next Steps

1. **Clone/branch** — Create a working branch for Phase 1 implementation.
2. **Module scaffold** — Set up TU-ACME.psd1, TU-ACME.psm1, Public/Private folders.
3. **First UC** — Implement UC-1.01 (module import) + unit test.
4. **Iterate** — Phase 1 usecases in priority order.
5. **CI/CD** — Verify tests pass on both PS 5.1 and PS 7+.
