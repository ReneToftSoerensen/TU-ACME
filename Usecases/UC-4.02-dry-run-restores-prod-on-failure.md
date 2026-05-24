# UC-4.02 — Dry-run restores prod even when ordering fails

**Behavior:** If `New-PACertificate` throws while the dry-run flow is active against the staging account, the `finally` block in `Invoke-DryRunOrder` still switches Posh-ACME back to the prod account. A failed dry-run never leaves the session pointed at staging.

**Given** `Invoke-DryRunOrder` is running against staging and `New-PACertificate` throws
**When** the exception propagates out of the `try` block
**Then** `Use-TUACMEProdAccount` is still called exactly once from the `finally` block

**Implementation:** `TU-ACME/Private/Certificates/Invoke-DryRunOrder.ps1`
**Test:** `tests/Unit/Certificates/UC-4.02.Tests.ps1`
