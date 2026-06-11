# Usecases — DOX Child

## Purpose

This folder contains 25 atomic usecase (UC) files that define feature requirements, acceptance criteria, implementation guidance, and test coverage for TU-ACME v2.

## Ownership

Owned by the project specification and development workflow. Each UC describes a single feature or behavior area with narrative, acceptance criteria (ACs), implementation hints, and test expectations.

## Local Contracts

- **Naming**: All usecase files follow the pattern `UC-<area>.<sequence>.md` (e.g., `UC-1.01.md`, `UC-4.03.md`).
- **Structure**: Each UC contains:
  - **Narrative** — Problem statement and context
  - **Acceptance Criteria** — Numbered AC statements (linked to ACCEPTANCE_CRITERIA.md)
  - **Implementation Notes** — Specific guidance for implementation
  - **Test Coverage** — Unit, Integration, or Scripts test guidance
- **Traceability**: Every AC in a UC must map to the parent traceability matrix in ACCEPTANCE_CRITERIA.md.
- **Immutability**: Once a UC is marked complete, changes require review and traceability audit.

## Work Guidance

1. **Before implementing**: Read the UC end-to-end.
2. **Write tests first**: Unit tests (mocked) or Integration tests (real store) per UC guidance.
3. **Implement**: Make tests pass; follow PS 5.1 compat and UTF-8 BOM rules from CLAUDE.md.
4. **Verify**: Run the Pester suite (Unit, Integration, Scripts tags).
5. **Commit**: Reference the UC(s) implemented (e.g., "Implement UC-1.01 (module import)").
6. **Update README.md**: Mark the UC as complete in the development checklist.

## Verification

- All 25 UC files exist and are named correctly.
- Each UC maps to one or more ACs in ACCEPTANCE_CRITERIA.md.
- All completed UCs are marked done in README.md development checklist.
- Tests for each UC pass (Unit, Integration, or Scripts).

## Child DOX Index

- No child folders require AGENTS.md.
