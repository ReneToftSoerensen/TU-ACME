
## Project Overview

- TU-ACME is a Windows PowerShell 5.1/7 TUI wrapper around Posh-ACME targeting a custom ACME certificate authority.
- TU-ACME is not a general-purpose ACME client.
- TU-ACME is focused on IIS server certificates and certificate renewal workflows.

## Tech Stack

- Windows PowerShell 5.1 and PowerShell 7
- Text-based user interface (TUI)
- Posh-ACME integration
- Custom ACME certificate authority
- IIS certificate deployment and renewal workflows

# DOX Framework

**DOX** is a durable documentation hierarchy of `AGENTS.md` files that define binding work contracts, ownership, local rules, and workflow guidance for every meaningful folder.

- Every contributor must follow DOX instructions across any edits.
- AGENTS.md files are binding work contracts for their subtrees.
- Work products and durable docs must stay understandable from the nearest AGENTS.md plus every parent AGENTS.md above it.

**Read the DOX methodology** in [docs/DOX.md](docs/DOX.md) before editing. It covers the reading chain, update rules, hierarchy, shape, style guide, and closeout checklist.

## User Preferences

When the user requests a durable behavior change, record it here or in the relevant child AGENTS.md

## Child DOX Index

- **SPEC.md** — Specification, design principles, platform requirements, architecture
- **ACCEPTANCE_CRITERIA.md** — 39 acceptance criteria across 10 feature areas with traceability matrix
- **CLAUDE.md** — Development framework, workflow, standards (this scope)
- **README.md** — Overview, phasing, usecase index, development checklist
- **docs/AGENTS.md** — Documentation navigation, DOX methodology reference, derived content
- **Usecases/AGENTS.md** — 25 atomic usecase files (UC-*.md), each with narrative, AC, implementation notes, test coverage
- **.claude/AGENTS.md** — Claude Code infrastructure, configuration, agents, and skills
