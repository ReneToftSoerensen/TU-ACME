# UC-7.01 — SMTP saves config when summary confirmed

**Behavior:** `Invoke-SMTPConfigure` collects the SMTP fields, shows a summary, and calls `Set-TUACMEConfig` exactly once when the operator confirms with `y`; on any other answer (including the default Enter) it prints `Cancelled` and does not call `Set-TUACMEConfig`.

**Given** a fully-prompted SMTP configuration session where the operator entered a valid host, port, SSL flag, auth flag, sender, and recipient
**When** the summary prompt receives `y`
**Then** `Set-TUACMEConfig` is called once with the new `Email` block, and on any non-`y` answer `Set-TUACMEConfig` is not called

**Implementation:** `TU-ACME/Private/Automation/Invoke-SMTPConfig.ps1`
**Test:** `tests/Unit/Automation/UC-7.01.Tests.ps1`
