# TU-ACME v2 — Development Infrastructure (DOX & Agents)

This document explains the **DOX framework** (durable documentation hierarchy) and the **`.claude/` infrastructure** that support development workflow, code quality, and automation for TU-ACME v2.

## What is DOX?

**DOX** is a lightweight hierarchy of `AGENTS.md` files that define binding work contracts, ownership, local rules, and workflow guidance for every folder in the repository.

- **Root `AGENTS.md`** — Project-wide instructions, global preferences, durable rules, and the top-level child index.
- **Child `AGENTS.md` files** — Domain-specific rules, scope boundaries, local contracts, and child indexes nested one level deeper.
- **No child may weaken DOX** — Child docs can add detail and local rules, but cannot override parent contracts.

### Why DOX Exists

Code, tests, and documentation grow in different directions. Without a clear ownership map:
- New contributors don't know which docs to read before editing a path.
- Changes to stable contracts get made without audit.
- Rules rot or become contradictory across the codebase.

DOX solves this by anchoring every meaningful folder to a durable, hierarchical contract.

## Reading the DOX Chain

Before editing **any** file or folder:

1. **Start at the repository root** and read `AGENTS.md`.
2. **Identify the target path** — What folders will you touch?
3. **Walk from root to target** — Follow every `AGENTS.md` in the path.
4. **Use the nearest doc** — The closest `AGENTS.md` is your local contract.
5. **Check parent docs** — Understand broader rules that apply to your scope.

### Example

To implement a use case (e.g., `Usecases/UC-1.01.md`):

1. Read `/AGENTS.md` — Project-wide DOX rules and child index.
2. Read `Usecases/AGENTS.md` — Usecase naming, structure, traceability, and workflow.
3. You are now ready to implement `UC-1.01.md`.

## DOX Hierarchy in TU-ACME

```
/AGENTS.md (root DOX, project-wide rules)
├── SPEC.md
├── ACCEPTANCE_CRITERIA.md
├── CLAUDE.md
├── README.md
├── Usecases/AGENTS.md
│   └── 25 usecase files (UC-*.md)
└── .claude/AGENTS.md (Claude Code infrastructure)
    ├── agents/AGENTS.md
    │   └── 3 specialized agent definitions
    ├── skills/AGENTS.md
    │   └── 8 project automation skills
    └── memory/ (reference docs for common pitfalls)
```

## `.claude/` Directory Structure

The `.claude/` folder contains all Claude Code (IDE integration) configuration, custom agents, and automation skills.

### **settings.json**

Claude Code harness configuration for the TU-ACME project. Contains:
- **Permissions** — Which tools are allowed (Bash, file read/write, etc.).
- **Environment variables** — PROJECT-specific vars for build/test.
- **Hooks** — Shell commands that run before/after events (e.g., pre-commit validation).
- **Harness behavior** — Preferred model, timeout, output mode.

Changes to `settings.json` must align with locked decisions in `CLAUDE.md`.

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

## Development Workflow with DOX & Agents

### Before You Start Coding

1. **Read the DOX chain** — Follow the path from root to your target folder.
2. **Understand the local contract** — Know the naming, structure, and verification rules.
3. **Read the relevant UC** — Understand narrative, AC, and implementation hints.

### During Development

1. **Write tests first** — Follow UC test guidance (Unit, Integration, or Scripts).
2. **Implement** — Follow PS 5.1 compatibility and UTF-8 BOM rules (see `CLAUDE.md`).
3. **Run verification** — Use `/verify-utf8-bom`, `/run-pester`, and `/code-review` as needed.
4. **Check agents** — If changes touch:
   - PowerShell code → **ps51-compat-linter**
   - Posh-ACME integration → **posh-acme-wrapper-reviewer**
   - TUI menus → **tui-pattern-checker**

### After You Commit

1. **Update DOX** — If your change affects structure, ownership, contracts, or workflows, update the nearest `AGENTS.md`.
2. **Update parent docs** — If parent-level structure changes, update parent `AGENTS.md`.
3. **Mark UC complete** — Update the checkbox in `README.md` development checklist.

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
- **`CLAUDE.md`** — Development standards and locked decisions.
