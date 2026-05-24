# UC-8.04 — Scheduled task setup runs as SYSTEM with highest run level

**Behavior:** The principal passed to `Register-ScheduledTask` is built via `New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest`. This ensures the renewal job sees the same `%ProgramData%\Posh-ACME\` store as the admin who configured TU-ACME.

**Given** the operator confirms registration
**When** `Register-ScheduledTask` is called
**Then** the principal argument has `UserId = 'SYSTEM'` and `RunLevel = 'Highest'`

**Implementation:** `TU-ACME/Private/Automation/Invoke-ScheduledTaskSetup.ps1`
**Test:** `tests/Unit/Automation/UC-8.04.Tests.ps1`
