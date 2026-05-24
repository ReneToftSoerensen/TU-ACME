# UC-1.07 — Confirmation summary defaults to No

**Behavior:** Anything other than `y` / `Y` at the `Proceed?` prompt cancels the wizard without writing config or creating accounts.

**Given** valid prod URL, staging URL, and contact email have been entered
**When** the user answers `n` (or empty) at the `Proceed? (y/N)` prompt
**Then** `Set-TUACMEConfig` and `New-PAAccount` are NOT called, and the wizard returns

**Implementation:** `TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1`
**Test:** `tests/Unit/Bootstrap/UC-1.07.Tests.ps1`
