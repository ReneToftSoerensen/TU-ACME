# TU-ACME v2 — Development Standards

## Code Quality

- **UTF-8 with BOM** — All `*.ps1`, `*.psm1`, `*.psd1` files (Windows PowerShell 5.1 requirement).
- **PS 5.1 compatible** — No `??`, `?.`, `?[`, ternary `a ? b : c`, `using namespace`, `ConvertFrom-Json -AsHashtable`, `ForEach-Object -Parallel`, etc.
- **English only** — All identifiers, comments, commit messages, and documentation in English.
- **Minimal comments** — Explain WHY, not WHAT. Trust well-named identifiers.
- **No pre-emptive abstractions** — Three similar lines is OK; don't abstract until needed.

## Security

- **Read-Host -AsSecureString** for SMTP password and DNS credentials only.
- **DPAPI encryption** (keyless, scoped to the writing user on this machine) for credentials stored in `config.json`.
- **Plaintext URLs and account IDs** — Deliberate and non-sensitive; do not encrypt.
- **No credential logging** — Log presence and result only; never log credential bodies.

## TUI Standards

- **Menu titles** — ≤79 characters (enforced).
- **Colors** — Cyan and DarkCyan only (no Red, Green, Yellow, etc.).
- **Navigation** — Arrow keys (up/down), Enter to select, `/` to search.
- **Disabled items** — Tracked via `DisabledIndices` array; skipped during navigation.
- **Search** — Case-insensitive, filters matching items.

See UC-4.01–4.03 for detailed specifications.

## Testing Strategy

**Three-tier Pester suite:**

1. **Unit** (`-Tag Unit`) — Mocked Posh-ACME and file I/O. Pure function testing.
2. **Integration** (`-Tag Integration`) — Real Posh-ACME store on disk. Wiring and data flow.
3. **Scripts** (`-Tag Scripts`) — Fake objects, renewal and deployment scripts end-to-end.

**Each UC includes test coverage guidance.** Every new feature lands with tests.
