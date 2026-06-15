---
name: code-style
description: Use whenever writing or reviewing TU-ACME code — implementing a UC, adding a function, or editing tests. Captures the project's PowerShell style so new code reads like existing code.
---

Follow these conventions for every `.ps1`/`.psm1`/`.psd1` change. They are distilled
from the Phase 1 codebase; when in doubt, imitate an existing file in the same folder.

## File layout

- One function per file, file named exactly after the function:
  `TU-ACME/Private/<Area>/Verb-TUACMENoun.ps1` (Areas: `Bootstrap`, `Certificates`,
  `Helpers`, `UI`, `Automation`, `IIS`). Public cmdlets go in `TU-ACME/Public/` and must be
  added to `FunctionsToExport` in the manifest and `Export-ModuleMember` in the psm1.
- Mirrored test file per function: `tests/Unit/<Area>/Verb-TUACMENoun.Tests.ps1`.
- Every PowerShell file starts with a UTF-8 BOM (`EF BB BF`). Run the `fix-bom` skill after
  creating files.

## Function shape

```powershell
function Verb-TUACMENoun {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Domain,

        [bool]$RequireAccountIds = $true,

        [switch]$DryRun
    )
    ...
    return $result
}
```

- Always `[CmdletBinding()]`; add `[OutputType()]` when the function returns a value.
- Explicit types on every parameter; `[Parameter(Mandatory = $true)]` spelled out (not bare
  `[Parameter(Mandatory)]`); blank line between parameters.
- Approved verbs only; nouns carry the `TUACME` prefix.
- Explicit `return` for produced values; discard unwanted output with `$null = ...`
  (never `| Out-Null`).

## PowerShell 5.1 floor (hard rules, AST-enforced in CodeQuality tests)

- Banned: `??`, `??=`, `?.`, `?[`, ternary `a ? b : c`, `&&`/`||` pipeline chains,
  `using namespace`, `ConvertFrom-Json -AsHashtable`, `ForEach-Object -Parallel`.
- `$null` comparisons put `$null` on the left: `if ($null -eq $config)`.
- String emptiness via `[string]::IsNullOrEmpty([string]$value)` /
  `IsNullOrWhiteSpace`, never truthiness (`if (!$x)`).
- Format strings with the `-f` operator: `('Failed: {0}' -f $_.Exception.Message)` — not
  interpolation with subexpressions.
- Defensive array wrapping for enumeration: `$items = @(Get-ChildItem ...)`.
- Cross-edition .NET over edition-specific cmdlets (e.g. `[System.Diagnostics.EventLog]`
  instead of `Write-EventLog`, which PS 7 lacks).

## Bottlenecks (never bypass; AST-enforced where noted)

- `Set-PAServer` / `Set-PAAccount` are called **only** by `Use-TUACMEProdAccount` /
  `Use-TUACMEStagingAccount` (enforced by `tests/Unit/CodeQuality.Tests.ps1`).
- Config I/O only via `Get-TUACMEConfig` / `Save-TUACMEConfig`; paths only via
  `Get-TUACMEConfigPath` (honours the `TUACME_DATA_DIR` test override).
- Event Log writes only via `Write-TUACMEEventLog` — it never throws; new event ids are
  reserved with the `register-event-id` skill and documented in UC-8.01's catalog.
- Posh-ACME availability via `Import-TUACMEPoshACME`; platform checks via
  `Test-TUACMEIsWindows`. Wrap Posh-ACME, never reimplement ACME logic.

## Output & errors

- `Write-Host` only in UI-facing code, colors restricted to `Cyan` (text/info) and
  `DarkCyan` (chrome/prompts) — no other colors, including for errors.
- `Write-Warning` for degraded-but-continuing paths; `Write-Verbose` for diagnostics.
- `throw` with an actionable message that names the remediation:
  `throw 'Posh-ACME is required ... Install it with: Install-Module Posh-ACME'`.
- Module import must never prompt or throw (AC-A.1): initialization failures downgrade to
  warnings.
- Never log credential bodies; log presence and outcome only.

## Comments

- English only. Minimal: explain WHY (constraints, non-obvious interactions, AC references),
  never WHAT the next line does. Reference ACs/UCs where a rule is load-bearing,
  e.g. `# Import must never prompt or fail (AC-A.1)`.

## Tests (Pester 5)

- `Describe '<Function> (UC-x.yy / AC-Z.n)' -Tag 'Unit'`; `It` names read as behavior
  sentences ('returns the previously active server URL').
- `BeforeAll` dot-sources `tests/Bootstrap.ps1` via
  `. (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')`.
- Mock module-internal and Posh-ACME commands with `Mock -ModuleName 'TU-ACME'`; invoke
  private functions through `InModuleScope 'TU-ACME' { ... }`.
- Posh-ACME and Windows-only commands resolve through stub modules in `tests/Fixtures/`
  (each stub throws unless mocked) — unit tests never require real Posh-ACME or Windows.
- Isolate config per test: `$env:TUACME_DATA_DIR = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))`
  in `BeforeEach`.
- Assert interactions with `Should -Invoke -ModuleName 'TU-ACME' <Cmd> -Times 1 -Exactly -ParameterFilter { ... }`.
- The Unit tier stays under 10 seconds; everything mocked or on `$TestDrive`.

## Commits

- One commit per UC, message starts with the UC id:
  `Implement UC-3.01 (dry-run wrapper)`. Closeout commits tick AC boxes in
  `ACCEPTANCE_CRITERIA.md` and statuses in `README.md` / `docs/planning-and-traceability.md`.
