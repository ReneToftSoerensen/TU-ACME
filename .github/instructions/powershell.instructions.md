---
applyTo: "**/*.ps1,**/*.psm1,**/*.psd1"
---

# PowerShell conventions (PoshTUI)

Authoritative style for all PowerShell in this repo. Keep code explicit and
readable over clever or terse.

## Structure
- `#requires -Version 7.0` and `#requires -RunAsAdministrator` where applicable.
- `Set-StrictMode -Version Latest`; set `$ErrorActionPreference = 'Stop'` at
  module/script scope.
- One function per concern; functions are PascalCase using an **approved verb**
  (`Get-Verb`). Private helpers stay in `Private/`, exported commands in `Public/`.

## Cmdlet usage
- **Full cmdlet names, never aliases** (`Where-Object` not `?`, `ForEach-Object`
  not `%`, `Get-ChildItem` not `gci`).
- Explicitly typed parameters with `[Parameter()]` attributes; mark mandatory
  params mandatory.
- State-changing functions: `[CmdletBinding(SupportsShouldProcess)]` and gate the
  change with `if ($PSCmdlet.ShouldProcess($target, $action))`. This is what makes
  `-WhatIf` work end to end.

## Output
- This project is a TUI: `Write-Host` is the correct channel for the on-screen
  interface (banner, menus, colored status). That is an intentional exception to
  the usual "no Write-Host" guidance.
- Functions that produce data return **objects** (`[pscustomobject]`), never host
  text. Don't mix UI writes into data-returning helpers.

## Errors
- Wrap each user action / per-item loop in `try/catch`; log via the shared
  `Write-PoshTuiLog` / `Write-Err` and keep the menu loop alive.
- In loops over multiple certs/orders/bindings, isolate failures so one bad item
  doesn't abort the batch; aggregate and report counts.

## Examples

```powershell
# Preferred: approved verb, typed params, ShouldProcess, full cmdlet names
function Update-IISCertificateBinding {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$SiteName,
        [Parameter(Mandatory)][string]$BindingInformation,
        [Parameter(Mandatory)][string]$Thumbprint,
        [string]$StoreName = 'WebHosting'
    )
    if (-not $PSCmdlet.ShouldProcess("$SiteName / $BindingInformation", "rebind -> $Thumbprint")) { return }
    # ...
}
```

```powershell
# Avoid: aliases, untyped params, no ShouldProcess, swallowed errors
function rebind ($s,$b,$t) {
    gci ... | ? { $_.x } | % { ... }   # aliases
}
```

## Quality gate
- `Invoke-ScriptAnalyzer -Path ./src -Recurse` must pass with no warnings/errors.
- Add Pester 5 tests for new pure functions (parsing, ordering, conversions).
