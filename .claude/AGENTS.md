# .claude — DOX Child

## Purpose

This folder contains Claude Code infrastructure, configuration, and documentation for the TU-ACME project:
- **settings.json** — Claude Code harness configuration
- **agents/** — Specialized agent definitions for code review and validation
- **skills/** — Project automation skills and helper commands
- **memory/** — Reference documentation and pitfall notes (created as needed)

## Ownership

Owned by the development workflow and project infrastructure. Managed alongside code review, testing, and build automation.

## Local Contracts

- **settings.json**: Contains permissions, environment variables, hooks, and harness behavior configuration. Changes require verification against CLAUDE.md locked decisions and PS 5.1 compat rules.
- **agents/**: Custom specialized agents for code validation (ps51-compat-linter, posh-acme-wrapper-reviewer, tui-pattern-checker).
- **skills/**: Project-specific automation (bump-version, verify-utf8-bom, run-pester, register-event-id, etc.).
- **memory/**: Durable reference docs for common pitfalls, PS 5.1 edge cases, Posh-ACME integration notes.

## Work Guidance

- Before editing settings.json, verify the change aligns with CLAUDE.md locked decisions.
- New agents or skills are added as durable tools; update this AGENTS.md when added.
- Memory notes are reference docs; keep them current with discovered issues or workarounds.

## Verification

- settings.json is valid JSON and referenced in CLAUDE.md.
- All agents and skills are documented and discoverable.
- Memory notes reflect current project state and real issues encountered.

## Child DOX Index

- **agents/AGENTS.md** — Specialized agent definitions and workflow
- **skills/AGENTS.md** — Project automation skills and commands
