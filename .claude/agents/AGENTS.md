# agents — DOX Child

## Purpose

This folder contains specialized agent definitions that enforce code quality standards and architectural constraints during development and review of TU-ACME v2.

## Ownership

Owned by the development team. Each agent is a durable tool invoked during code review or pre-commit to validate compliance with project standards.

## Local Contracts

- **Naming**: Agent definition files follow the pattern `<agent-name>.md`.
- **Content**: Each agent definition includes:
  - Purpose and scope (what it checks)
  - Invocation triggers (when it runs)
  - Rules and constraints (what it enforces)
  - Examples of pass/fail cases
- **Three core agents**:
  - **ps51-compat-linter.md** — Enforces Windows PowerShell 5.1 syntax compatibility (no `??`, `?.`, ternary, `using namespace`, etc.)
  - **posh-acme-wrapper-reviewer.md** — Ensures Posh-ACME integration correctness (bootstrap functions only, account isolation, dry-run safety)
  - **tui-pattern-checker.md** — Validates TUI menu patterns (title length, color rules, navigation, disabled items)

## Work Guidance

- New agents are added only when a persistent validation rule exists across multiple UCs or commits.
- Each agent must be documented in its own .md file with examples.
- Update this AGENTS.md when agents are added, removed, or significantly refactored.

## Verification

- All agent .md files are well-formed and include examples.
- Agents are invoked automatically (pre-commit hooks or manual review as documented).
- Rules in each agent map to CLAUDE.md locked decisions or ACCEPTANCE_CRITERIA.md ACs.

## Child DOX Index

- No child folders require AGENTS.md.
