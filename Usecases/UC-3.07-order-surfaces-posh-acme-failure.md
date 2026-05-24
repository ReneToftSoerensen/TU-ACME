# UC-3.07 — Order surfaces Posh-ACME failure as a yellow message

**Behavior:** When `New-PACertificate` throws (rate limit, validation failure, network error, etc.), `Invoke-OrderCertificate` catches the terminating error, prints a yellow `  Order failed: <msg>` line, does not write Event 1003, and does not propagate the exception to the TUI caller.

**Given** a prod-initialized TU-ACME with a configured plugin and valid plugin args
**When** `New-PACertificate` throws `rate-limited`
**Then** `Invoke-OrderCertificate` returns without throwing and `Write-EventLogEntry` is never called with `EventId 1003`

**Implementation:** `TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1`
**Test:** `tests/Unit/Certificates/UC-3.07.Tests.ps1`
