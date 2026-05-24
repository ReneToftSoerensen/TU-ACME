# UC-2.03 — Use-TUACME*Account throws when config not initialized

**Behavior:** Both `Use-TUACMEProdAccount` and `Use-TUACMEStagingAccount` refuse to reconfigure Posh-ACME if the persisted configuration has not been initialized. The terminating error is raised before any `Set-PAServer` or `Set-PAAccount` call is made, so the active Posh-ACME session is left untouched.

**Given** `config.Acme.Initialized = $false`
**When** `Use-TUACMEProdAccount` or `Use-TUACMEStagingAccount` is invoked
**Then** a terminating error containing `not initialized` is thrown, and neither `Set-PAServer` nor `Set-PAAccount` is called

**Implementation:** `TU-ACME/Private/Bootstrap/Use-TUACMEProdAccount.ps1`, `TU-ACME/Private/Bootstrap/Use-TUACMEStagingAccount.ps1`
**Test:** `tests/Unit/Bootstrap/UC-2.03.Tests.ps1`
