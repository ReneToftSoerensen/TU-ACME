# UC-5.01 — Dashboard calls Use-TUACMEProdAccount first

**Behavior:** `Invoke-CertificateDashboard` invokes `Use-TUACMEProdAccount` before any Posh-ACME cmdlet so listings always reflect the production directory.

**Given** the operator has selected the dashboard menu entry
**When** `Invoke-CertificateDashboard` is invoked
**Then** `Use-TUACMEProdAccount` is called at least once, and the first `Get-PACertificate` invocation only happens afterwards

**Implementation:** `TU-ACME/Private/Certificates/Invoke-CertificateDashboard.ps1`
**Test:** `tests/Unit/Certificates/UC-5.01.Tests.ps1`
