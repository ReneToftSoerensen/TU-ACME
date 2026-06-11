# skills — DOX Child

## Purpose

This folder contains project automation skills — reusable commands and helpers that support development, testing, and verification workflows for TU-ACME v2.

## Ownership

Owned by the development team. Skills are durable tools invoked during development, testing, and deployment.

## Local Contracts

- **Naming**: Skill definition files follow the pattern `<skill-name>.md`.
- **Content**: Each skill definition includes:
  - Purpose and use cases
  - Invocation syntax (how to call it)
  - Expected inputs and outputs
  - Examples
- **Core skills**:
  - **verify-utf8-bom.md** — Verify all .ps1, .psm1, .psd1 files have UTF-8 BOM
  - **run-pester.md** — Run Pester test suite with specified tags (Unit, Integration, Scripts)
  - **posh-acme-expert.md** — Reference for Posh-ACME integration patterns and edge cases
  - **powershell-5.1-expert.md** — Reference for PS 5.1 compatibility and pitfalls
  - **new-private-function.md** — Scaffold new private function with UTF-8 BOM and template
  - **bump-version.md** — Update version number in .psd1 manifest
  - **add-use-case.md** — Create new usecase .md file from template
  - **register-event-id.md** — Reserve and register Windows Event Log event IDs

## Work Guidance

- New skills are added when a repeated task or verification check exists.
- Each skill must be documented in its own .md file with examples.
- Skills should be idempotent or clearly document side effects.
- Update this AGENTS.md when skills are added, removed, or significantly refactored.

## Verification

- All skill .md files are well-formed and include invocation examples.
- Skills are discoverable and callable during development.
- Each skill maps to a durable need (testing, validation, scaffolding, or reference).

## Child DOX Index

- No child folders require AGENTS.md.
