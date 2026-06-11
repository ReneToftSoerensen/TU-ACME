# UC-8.09 — Renewal script runs its body inside the loaded module's scope

## Trigger

`Invoke-RenewalBackground.ps1` is invoked either by the Posh-ACME-AutoRenewal
scheduled task (SYSTEM context, fresh PowerShell session) or interactively
from the Automation menu's **"Run renewal now (foreground)"** entry
(`& $scriptPath -Foreground` from `Invoke-AutomationMenu.ps1`).

## Behaviour

The script resolves the loaded `TU-ACME` module via `Get-Module TU-ACME`
and, only when no module is loaded yet (the SYSTEM / scheduled-task path),
imports it **without `-Force`**. The renewal body then runs inside that
module instance's scope via `& $module { ... }`, so it can call
module-private helpers (`Use-TUACMEProdAccount`, `Write-EventLogEntry`,
`Get-TUACMEConfig`, `Send-TUACMEMail`) directly.

## Why

Two failure modes the old shape produced in real use:

1. **Private helpers invisible.** `& script.ps1` runs the script in a child
   of the global scope, not the module's scope. `Import-Module TU-ACME`
   only brings the **exported** functions (just `Start-TUACME`) into the
   caller's scope. The script's calls to `Write-EventLogEntry` therefore
   failed with *"The term 'Write-EventLogEntry' is not recognized…"* the
   first time the renewal hit Event 1001 or Event 3001.
2. **In-flight module torn down.** The previous shape opened with
   `Import-Module TU-ACME -Force`, which removes and re-imports the
   currently executing module object. When the renewal was launched from
   the running TUI, the parent `Invoke-AutomationMenu` returned to its
   `while` loop only to find its own private symbols (`Show-Menu`,
   `Wait-AnyKey`, …) gone, because they belonged to the old module
   instance that `-Force` had just replaced.

Running the body via `& $module { ... }` solves both: the body sees
private helpers and the parent's module instance is left intact.

## Pester

`tests/Scripts/Invoke-RenewalBackground.Tests.ps1` — case "UC-8.09: does
not -Force re-import the running TU-ACME module" asserts that
`Import-Module` is never called (and certainly never with `-Force`) when
the module is already loaded.
