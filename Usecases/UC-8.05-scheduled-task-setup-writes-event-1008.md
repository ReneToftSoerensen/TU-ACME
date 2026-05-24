# UC-8.05 — Scheduled task setup writes Event 1008 on success

**Behavior:** After a successful `Register-ScheduledTask`, `Invoke-ScheduledTaskSetup` emits a single `Write-EventLogEntry -EventId 1008 -EntryType Information` describing the registered task name, time, and run-as account.

**Given** `Register-ScheduledTask` completes without throwing
**When** `Invoke-ScheduledTaskSetup` returns
**Then** `Write-EventLogEntry -EventId 1008` is called exactly once

**Implementation:** `TU-ACME/Private/Automation/Invoke-ScheduledTaskSetup.ps1`
**Test:** `tests/Unit/Automation/UC-8.05.Tests.ps1`
