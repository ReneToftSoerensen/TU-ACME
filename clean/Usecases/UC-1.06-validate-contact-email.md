# UC-1.06 — Prompt and validate contact email

**Behavior:** The wizard rejects contact emails that do not match `^[^@\s]+@[^@\s]+\.[^@\s]+$` and re-prompts until a valid address is given.

**Given** the wizard is at the contact email prompt
**When** the user first enters `not-an-email` and then `ops@example.com`
**Then** the wizard issues at least two Read-Host calls for the contact email prompt

**Implementation:** `TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1`
**Test:** `tests/Unit/Bootstrap/UC-1.06.Tests.ps1`
