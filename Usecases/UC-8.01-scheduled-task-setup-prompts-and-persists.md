# UC-8.01 — Scheduled task setup prompts for and persists name/time/account

**Behavior:** `Invoke-ScheduledTaskSetup` reads `Get-TUACMEConfig` and surfaces the current `ScheduledTask.{TaskName,RunTime,RunAsAccount}` values as defaults. After the operator confirms registration, the function persists the (possibly edited) values back to disk via `Set-TUACMEConfig`.

**Given** the config has defaults `Posh-ACME-AutoRenewal`, `03:00`, `SYSTEM`
**When** the operator runs `Invoke-ScheduledTaskSetup` and accepts the defaults
**Then** `Set-TUACMEConfig` is called exactly once with `ScheduledTask.TaskName`, `RunTime`, and `RunAsAccount` populated

**Implementation:** `TU-ACME/Private/Automation/Invoke-ScheduledTaskSetup.ps1`
**Test:** `tests/Unit/Automation/UC-8.01.Tests.ps1`
