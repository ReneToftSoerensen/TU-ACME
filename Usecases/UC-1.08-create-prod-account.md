# UC-1.08 — Create prod ACME account

**Behavior:** After confirmation, the wizard calls `Set-PAServer -DirectoryUrl <prodUrl>` followed by `New-PAAccount -Contact <email> -AcceptTOS` for the prod environment and captures the returned account id.

**Given** valid prod URL, staging URL, contact email, and `y` at the confirmation prompt
**When** the wizard runs to completion
**Then** `Set-PAServer` is invoked with the prod URL and `New-PAAccount -AcceptTOS` is invoked with the contact email; the resulting id is persisted as `ProdAccountId`

**Implementation:** `TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1`
**Test:** `tests/Unit/Bootstrap/UC-1.08.Tests.ps1`
