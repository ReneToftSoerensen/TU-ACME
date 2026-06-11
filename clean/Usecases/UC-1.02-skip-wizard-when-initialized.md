# UC-1.02 — Skip wizard when already initialized

**Behavior:** When `config.Acme.Initialized` is `$true` and `-Force` is not given, `Initialize-TUACMEEnvironment` returns without prompting.

**Given** `config.json` has `Acme.Initialized = $true`
**When** `Initialize-TUACMEEnvironment` is invoked without `-Force`
**Then** no Read-Host prompts occur and the function returns

**Implementation:** `TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1`
**Test:** `tests/Unit/Bootstrap/UC-1.02.Tests.ps1`
