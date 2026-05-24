# UC-1.03 — Force re-init bypasses initialized flag

**Behavior:** When `-Force` is passed, the wizard runs even when `config.Acme.Initialized = $true`.

**Given** `config.json` has `Acme.Initialized = $true`
**When** `Initialize-TUACMEEnvironment -Force` is invoked
**Then** the wizard prompts for the prod ACME directory URL

**Implementation:** `TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1`
**Test:** `tests/Unit/Bootstrap/UC-1.03.Tests.ps1`
