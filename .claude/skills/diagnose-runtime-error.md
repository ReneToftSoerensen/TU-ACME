---
name: diagnose-runtime-error
description: Use when the user pastes a raw PowerShell error from a running TU-ACME session (e.g. "X is not recognized", `CommandNotFoundException`, exception at `<File>.ps1:<line>`). Drives a fixed checklist to find the root cause instead of guessing.
---

Most TU-ACME runtime errors fall into one of four buckets. Walk them in order; stop at the first match.

## 1. Private helper not dot-sourced

`<Name> is not recognized as a name of a cmdlet, function, script file, or operable program` for a `Verb-Noun` symbol almost always means a private helper exists but `TU-ACME.psm1` does not dot-source it.

- `Grep` for `function <Name>` under `TU-ACME/Private/`.
- If a definition exists, open `TU-ACME/TU-ACME.psm1` and verify the file is dot-sourced (the module enumerates `Private/**/*.ps1` — confirm the new file matches the pattern and is not gated by an `if`).
- Fix by adding the missing dot-source / correcting the path. Do not add the symbol to `FunctionsToExport` — private helpers stay private.

## 2. Stale install on the target machine

If the helper exists in source **and** is dot-sourced, the running process is loading an old copy from `$env:ProgramFiles\WindowsPowerShell\Modules\TU-ACME\`.

- Tell the user to re-run `deploy.ps1` (or `Copy-Item` the module folder) and reopen the PowerShell session — `Import-Module -Force` is not enough if the file is missing on disk.
- Background renewal runs as SYSTEM; if the error came from the scheduled task, the SYSTEM-visible module path must also be refreshed.

## 3. Missing UTF-8 BOM

PS 5.1 parses BOM-less files as ANSI, which silently mangles non-ASCII identifiers and string literals. Symptoms: parse errors, "unexpected token", or functions defined in a file that PS 5.1 refuses to load.

- Check the suspect file with `head -c 3 <file> | od -An -tx1` → must be `ef bb bf`.
- If missing, invoke the `verify-utf8-bom` skill to sweep the tree.

## 4. PS 5.1 vs PS 7 syntax drift

If the error only reproduces on PS 5.1, suspect PS 7-only syntax (`??`, `?.`, `?[`, ternary `a ? b : c`, top-level `&&`/`||`, `using namespace`, `ConvertFrom-Json -AsHashtable`, `ForEach-Object -Parallel`).

- Invoke the `powershell-5.1-expert` skill or the `ps51-compat-linter` agent on the offending file.

## Reporting

After identifying the bucket, report: which bucket, the file/line, and the minimal fix. Do **not** also propose unrelated cleanups — the user is debugging, not refactoring.
