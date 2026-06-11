# UC-1.01 — Detect uninitialized config triggers wizard

**Behavior:** When `Initialize-TUACMEEnvironment` runs and `config.Acme.Initialized` is `$false`, the first-run wizard proceeds (prompts the user).

**Given** `config.json` has `Acme.Initialized = $false` (or is missing)
**When** `Initialize-TUACMEEnvironment` is invoked
**Then** the wizard prompts for the prod ACME directory URL (i.e. it does not silently return)

**Implementation:** `TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1`
**Test:** `tests/Unit/Bootstrap/UC-1.01.Tests.ps1`
