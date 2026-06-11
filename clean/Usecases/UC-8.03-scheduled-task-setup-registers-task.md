# UC-8.03 — Scheduled task setup registers task via Register-ScheduledTask

**Behavior:** Once the operator has confirmed the task name, run time, and run-as account (and accepted overwrite if applicable), `Invoke-ScheduledTaskSetup` builds an action that runs `powershell.exe -NonInteractive -WindowStyle Hidden -File <Invoke-RenewalBackground.ps1>`, a daily trigger at the chosen time, and a principal, then calls `Register-ScheduledTask -Force` exactly once.

**Given** no existing task (or the operator confirmed overwrite)
**When** `Invoke-ScheduledTaskSetup` completes its prompts
**Then** `Register-ScheduledTask` is invoked exactly once with the prepared action, trigger, and principal

**Implementation:** `TU-ACME/Private/Automation/Invoke-ScheduledTaskSetup.ps1`
**Test:** `tests/Unit/Automation/UC-8.03.Tests.ps1`
