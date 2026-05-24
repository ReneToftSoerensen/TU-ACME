# UC-4.01 — Dry-run uses staging then restores prod

**Behavior:** `Invoke-DryRunOrder` switches Posh-ACME to the staging account before ordering and switches back to the prod account in a `finally` block, so leaving the dry-run path never leaves the session pointed at staging.

**Given** an initialized TU-ACME (prod + staging accounts both present)
**When** `Invoke-DryRunOrder` is invoked
**Then** `Use-TUACMEStagingAccount` is called before `New-PACertificate`, and `Use-TUACMEProdAccount` is called in the `finally` block

**Implementation:** `TU-ACME/Private/Certificates/Invoke-DryRunOrder.ps1`
**Test:** `tests/Unit/Certificates/UC-4.01.Tests.ps1`
