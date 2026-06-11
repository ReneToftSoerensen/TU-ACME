# docs — DOX Child

## Purpose

This folder contains reorganized specification-driven development documentation derived from root documents (SPEC.md, ACCEPTANCE_CRITERIA.md, CLAUDE.md, README.md). It provides easier navigation and reference for contributors working on TU-ACME v2.

## Ownership

Owned by the project specification and development workflow. Documentation here is derived from and subordinate to root documents; updates to root docs cascade into updates here.

## Local Contracts

- **Organization**: Documentation is split into focused files (overview, architecture, standards, planning, operations, DOX reference, agents reference) for monorepo-friendly navigation.
- **Derivation**: All content is derived from root documents (SPEC.md, ACCEPTANCE_CRITERIA.md, CLAUDE.md, README.md). Root docs are authoritative; docs/ files must stay in sync.
- **No new contracts**: docs/ files are reference and navigation only; they do not establish new contracts or rules beyond what root documents define.

## Work Guidance

1. **Before editing a docs/ file**: Verify the change against the authoritative root document.
2. **Update cascade**: If a root document changes, check all derived docs/ files and update them accordingly.
3. **New documentation**: If adding a new doc file, add it to the Child DOX Index below and update docs/README.md if needed.
4. **DOX reference**: Use docs/DOX.md as the reference for the DOX framework and how to read DOX chains.

## Verification

- All .md files in docs/ have corresponding entries in the Child DOX Index.
- Content aligns with authoritative root documents (SPEC.md, ACCEPTANCE_CRITERIA.md, CLAUDE.md, README.md).
- docs/DOX.md accurately reflects the project's DOX methodology.

## Child DOX Index

- **DOX.md** — Durable Documentation Framework (hierarchy, reading chains, update rules, style guide, closeout checklist)
- **README.md** — Documentation index and quick navigation
- **overview.md** — Project purpose, quick start, development model, locked decisions
- **architecture.md** — Architecture, platform requirements, module structure
- **development-standards.md** — Code quality, security, TUI standards, testing strategy
- **planning-and-traceability.md** — Phases, feature areas, acceptance criteria mapping, development checklist
- **development-checklist.md** — Phase-level development checklist (plan through deploy)
- **operations-and-references.md** — Event IDs, usage guidance, references, FAQ
- **claude-infrastructure.md** — .claude/ directory, specialized agents, automation skills, development workflow
