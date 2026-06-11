# DOX — Durable Documentation Framework

DOX is a lightweight hierarchy of `AGENTS.md` files that define binding work contracts, ownership, local rules, and workflow guidance for every meaningful folder in the repository.

## Core Contract

- **AGENTS.md files are binding work contracts** for their subtrees.
- Work products, source materials, instructions, records, assets, and durable docs must stay understandable from the nearest applicable AGENTS.md plus every parent AGENTS.md above it.
- **No child doc may weaken DOX** — Child docs can add detail and local rules, but cannot override parent contracts.

## Read Before Editing

1. Read the root `AGENTS.md`.
2. Identify every file or folder you expect to touch.
3. Walk from the repository root to each target path.
4. Read every `AGENTS.md` found along each route.
5. If a parent AGENTS.md lists a child AGENTS.md whose scope contains the path, read that child and continue from there.
6. Use the nearest AGENTS.md as the local contract and parent docs for repo-wide rules.
7. If docs conflict, the closer doc controls local work details, but no child doc may weaken DOX.

**Do not rely on memory.** Re-read the applicable DOX chain in the current session before editing.

## Update After Editing

Every meaningful change requires a DOX pass before the task is done.

**Update the closest owning AGENTS.md when a change affects:**

- Purpose, scope, ownership, or responsibilities
- Durable structure, contracts, workflows, or operating rules
- Required inputs, outputs, permissions, constraints, side effects, or artifacts
- User preferences about behavior, communication, process, organization, or quality
- AGENTS.md creation, deletion, move, rename, or index contents

**Update parent docs when** parent-level structure, ownership, workflow, or child index changes. **Update child docs when** parent changes alter local rules. **Remove stale or contradictory text immediately.** Small edits that do not change behavior or contracts may leave docs unchanged, but the DOX pass still must happen.

## Hierarchy

- **Root AGENTS.md** — Project-wide instructions, global preferences, durable workflow rules, and the top-level Child DOX Index.
- **Child AGENTS.md files** — Domain-specific instructions and their own Child DOX Index.
- Each parent explains what its direct children cover and what stays owned by the parent.
- **The closer a doc is to the work, the more specific and practical it must be.**

## Child AGENTS.md Shape

**Create a child AGENTS.md when** a folder becomes a durable boundary with its own purpose, rules, responsibilities, workflow, materials, or quality standards.

**Default section order:**
1. Purpose
2. Ownership
3. Local Contracts
4. Work Guidance
5. Verification
6. Child DOX Index

**Work Guidance** must reflect the current standards of the project or user instructions; if there are no specific standards or instructions yet, leave it empty.

**Verification** must reflect an existing check; if no verification framework exists yet, leave it empty and update it when one exists.

## Style Guide

- Keep docs concise, current, and operational.
- Document stable contracts, not diary entries.
- Put broad rules in parent docs and concrete details in child docs.
- Prefer direct bullets with explicit names.
- Do not duplicate rules across many files unless each scope needs a local version.
- Delete stale notes instead of explaining history.
- Trim obvious statements, repeated rules, misplaced detail, and warnings for risks that no longer exist.

## Closeout Checklist

1. Re-check changed paths against the DOX chain.
2. Update nearest owning docs and any affected parents or children.
3. Refresh every affected Child DOX Index.
4. Remove stale or contradictory text.
5. Run existing verification when relevant.
6. Report any docs intentionally left unchanged and why.
