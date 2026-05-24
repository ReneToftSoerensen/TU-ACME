# UC-1.04 — Prompt and validate prod directory URL

**Behavior:** The wizard rejects prod URLs that do not start with `https://` and re-prompts until a valid value is given.

**Given** the wizard is at the prod directory URL prompt
**When** the user first enters `http://bad` and then `https://acme.corp/dir`
**Then** the wizard issues at least two Read-Host calls for the prod URL prompt

**Implementation:** `TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1`
**Test:** `tests/Unit/Bootstrap/UC-1.04.Tests.ps1`
