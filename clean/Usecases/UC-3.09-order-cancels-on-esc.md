# UC-3.09 — Order cancels and returns when Esc is pressed at any prompt

**Behavior:** `Invoke-OrderCertificate` reads each interactive prompt (domain, SANs, plugin, confirmation) via `Read-LineOrEscape`. If the operator presses Escape at any of them, the function prints `Cancelled (Esc).` and returns without calling `New-PACertificate` and without writing Event 1003.

**Given** an initialized TU-ACME (prod account present) and the operator runs `Invoke-OrderCertificate`
**When** the operator presses Esc at the domain, SANs, plugin, or confirmation prompt
**Then** the function returns; `New-PACertificate` is never invoked; `Write-EventLogEntry -EventId 1003` is never called

**Implementation:** `TU-ACME/Private/Helpers/Read-LineOrEscape.ps1`, `TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1`
**Test:** `tests/Unit/Certificates/UC-3.09.Tests.ps1`
