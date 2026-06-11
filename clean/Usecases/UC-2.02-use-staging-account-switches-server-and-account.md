# UC-2.02 — Use-TUACMEStagingAccount switches server and account

**Behavior:** Calling `Use-TUACMEStagingAccount` reads the persisted staging URL and account ID and reconfigures Posh-ACME's active server and active account in one call.

**Given** `config.Acme.Initialized = $true` with `StagingDirectoryUrl` and `StagingAccountId` populated
**When** `Use-TUACMEStagingAccount` is invoked
**Then** `Set-PAServer -DirectoryUrl <staging>` is called, followed by `Set-PAAccount -ID <stagingId>`

**Implementation:** `TU-ACME/Private/Bootstrap/Use-TUACMEStagingAccount.ps1`
**Test:** `tests/Unit/Bootstrap/UC-2.02.Tests.ps1`
