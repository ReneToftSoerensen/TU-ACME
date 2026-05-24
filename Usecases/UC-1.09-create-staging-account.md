# UC-1.09 — Create staging ACME account

**Behavior:** After confirmation, the wizard calls `Set-PAServer -DirectoryUrl <stagingUrl>` followed by `New-PAAccount -Contact <email> -AcceptTOS` for the staging environment and captures the returned account id.

**Given** valid prod URL, staging URL, contact email, and `y` at the confirmation prompt
**When** the wizard runs to completion
**Then** `Set-PAServer` is invoked with the staging URL and `New-PAAccount -AcceptTOS` is invoked again; the resulting id is persisted as `StagingAccountId`

**Implementation:** `TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1`
**Test:** `tests/Unit/Bootstrap/UC-1.09.Tests.ps1`
