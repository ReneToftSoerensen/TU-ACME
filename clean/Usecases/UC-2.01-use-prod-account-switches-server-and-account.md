# UC-2.01 — Use-TUACMEProdAccount switches server and account

**Behavior:** Calling `Use-TUACMEProdAccount` reads the persisted prod URL and account ID and reconfigures Posh-ACME's active server and active account in one call.

**Given** `config.Acme.Initialized = $true` with `ProdDirectoryUrl` and `ProdAccountId` populated
**When** `Use-TUACMEProdAccount` is invoked
**Then** `Set-PAServer -DirectoryUrl <prod>` is called, followed by `Set-PAAccount -ID <prodId>`

**Implementation:** `TU-ACME/Private/Bootstrap/Use-TUACMEProdAccount.ps1`
**Test:** `tests/Unit/Bootstrap/UC-2.01.Tests.ps1`
