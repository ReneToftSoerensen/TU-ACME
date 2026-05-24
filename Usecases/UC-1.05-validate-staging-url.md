# UC-1.05 — Prompt and validate staging directory URL

**Behavior:** The wizard rejects staging URLs that do not start with `https://` and re-prompts until a valid value is given.

**Given** the wizard is at the staging directory URL prompt
**When** the user first enters `ftp://bad` and then `https://staging.corp/dir`
**Then** the wizard issues at least two Read-Host calls for the staging URL prompt

**Implementation:** `TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1`
**Test:** `tests/Unit/Bootstrap/UC-1.05.Tests.ps1`
