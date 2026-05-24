# UC-3.01 — Order calls Use-TUACMEProdAccount before any Posh-ACME work

**Behavior:** `Invoke-OrderCertificate` switches Posh-ACME to the prod account as its very first action so every cert order lands on prod regardless of prior state.

**Given** a prod-initialized TU-ACME with a configured DNS plugin
**When** `Invoke-OrderCertificate` is invoked
**Then** `Use-TUACMEProdAccount` is called before `New-PACertificate`

**Implementation:** `TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1`
**Test:** `tests/Unit/Certificates/UC-3.01.Tests.ps1`
