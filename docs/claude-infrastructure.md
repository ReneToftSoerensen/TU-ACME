# TU-ACME v2 — Development Infrastructure (Agents & Skills)

This document explains the **`.claude/` infrastructure** that supports development workflow, code quality, and automation for TU-ACME v2.

**For DOX framework explanation** (durable documentation hierarchy, how to read the DOX chain, and hierarchy patterns), see [DOX.md](DOX.md).

## `.claude/` Directory Structure

The `.claude/` folder contains all Claude Code (IDE integration) configuration, custom agents, and automation skills.

### **settings.json**

Claude Code harness configuration for the TU-ACME project. Contains:
- **Permissions** — Which tools are allowed (Bash, file read/write, etc.).
- **Environment variables** — PROJECT-specific vars for build/test.
- **Hooks** — Shell commands that run before/after events (e.g., pre-commit validation).
- **Harness behavior** — Preferred model, timeout, output mode.

Changes to `settings.json` must align with the locked decisions in [overview.md](overview.md).

### **agents/** — Specialized Agent Definitions

Custom agents that enforce code quality and architectural constraints during development and review.

#### Three Core Agents

1. **ps51-compat-linter** — Enforces Windows PowerShell 5.1 syntax compatibility.
   - Rejects: `??`, `?.`, ternary (`? :`), `using namespace`, `[switch]` parameter defaults, etc.
   - Ensures code runs on both PS 5.1 and PS 7.2+.

2. **posh-acme-wrapper-reviewer** — Validates Posh-ACME integration correctness.
   - Enforces: Bootstrap functions only (no direct `Set-PAServer`), account isolation, dry-run safety.
   - Prevents: Accidental misuse of Posh-ACME APIs that could corrupt state.

3. **tui-pattern-checker** — Validates TUI menu patterns and constraints.
   - Enforces: Title length, color rules, menu navigation, disabled-item handling.
   - Ensures: Consistent, accessible user experience across all menu flows.

**When agents run:**
- Manually via `/code-review` or `/simplify` skills.
- Automatically as part of pre-commit hooks (if configured).

### **skills/** — Project Automation Skills

Reusable commands that support development, testing, and verification workflows.

#### Core Skills

| Skill | Purpose |
|-------|---------|
| **verify-utf8-bom** | Verify all `.ps1`, `.psm1`, `.psd1` files have UTF-8 BOM. |
| **run-pester** | Run Pester test suite with specified tags (Unit, Integration, Scripts). |
| **bump-version** | Update version number in `.psd1` manifest. |
| **add-use-case** | Create new usecase `.md` file from template. |
| **register-event-id** | Reserve and register Windows Event Log event IDs. |
| **new-private-function** | Scaffold new private function with UTF-8 BOM and template. |
| **posh-acme-expert** | Reference for Posh-ACME integration patterns and edge cases. |
| **powershell-5.1-expert** | Reference for PS 5.1 compatibility and pitfalls. |

**How to use:**
```
/<skill-name>           # Invoke the skill (Claude Code harness)
```

### **memory/**

Reference documentation for common pitfalls, edge cases, and workarounds. Created as needed during development. Examples:
- PS 5.1 compatibility gotchas.
- Posh-ACME store behavior quirks.
- UTF-8 BOM enforcement rules.

## Development Workflow

1. **Read the DOX chain** (see [DOX.md](DOX.md)) — Follow the path from root to your target folder, reading all AGENTS.md files along the way.
2. **Read the relevant UC** — Understand narrative, AC, and implementation hints.
3. **Write tests first** — Follow UC test guidance (Unit, Integration, or Scripts).
4. **Implement** — Follow PS 5.1 compatibility and UTF-8 BOM rules (see [development-standards.md](development-standards.md)).
5. **Run verification** — Use `/verify-utf8-bom`, `/run-pester`, and `/code-review` as needed.
6. **Check specialized agents** — If changes touch:
   - PowerShell code → **ps51-compat-linter**
   - Posh-ACME integration → **posh-acme-wrapper-reviewer**
   - TUI menus → **tui-pattern-checker**
7. **Update AGENTS.md** — If your change affects structure, ownership, contracts, or workflows, update the nearest `AGENTS.md` (see [DOX.md](DOX.md) closeout checklist).
8. **Mark UC complete** — Update the checkbox in `README.md` development checklist.

## Quick Reference

| Need | Read/Do |
|------|---------|
| **Where do I edit X?** | Read `/AGENTS.md` → find the child index → follow the chain to your folder. |
| **What rules apply to my scope?** | Read the nearest `AGENTS.md` and every parent above it. |
| **Verify my changes?** | Use `/verify-utf8-bom` (files), `/run-pester` (tests), `/code-review` (quality). |
| **Add a new feature area?** | Create a new folder, read parent `AGENTS.md`, then create a child `AGENTS.md`. |
| **Common PS 5.1 issue?** | Check `.claude/memory/` or use `/powershell-5.1-expert`. |
| **Posh-ACME integration question?** | Use `/posh-acme-expert` or check `.claude/memory/`. |

## Links

- **`AGENTS.md`** — Root DOX and top-level child index.
- **`.claude/AGENTS.md`** — Claude Code infrastructure contract.
- **`.claude/agents/AGENTS.md`** — Specialized agent definitions.
- **`.claude/skills/AGENTS.md`** — Project automation skills.
- **`Usecases/AGENTS.md`** — Usecase files and traceability.
- **`CLAUDE.md`** — Root documentation map pointing into `docs/`.
- **[development-standards.md](development-standards.md)** — Development standards.
- **[overview.md](overview.md)** — Locked decisions.
