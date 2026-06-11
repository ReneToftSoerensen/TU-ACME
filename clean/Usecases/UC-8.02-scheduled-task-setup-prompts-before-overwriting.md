# UC-8.02 — Scheduled task setup prompts before overwriting existing task

**Behavior:** When `Get-ScheduledTask -TaskName $name` returns an existing task, `Invoke-ScheduledTaskSetup` asks the operator `Overwrite existing task? (y/N)`. The prompt defaults to No: any non-`y` answer cancels and `Register-ScheduledTask` is not called.

**Given** a scheduled task with the chosen name already exists
**When** the operator answers anything other than `y` to the overwrite prompt
**Then** `Register-ScheduledTask` is never called

**Implementation:** `TU-ACME/Private/Automation/Invoke-ScheduledTaskSetup.ps1`
**Test:** `tests/Unit/Automation/UC-8.02.Tests.ps1`
