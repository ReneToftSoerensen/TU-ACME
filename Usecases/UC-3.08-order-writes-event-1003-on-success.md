# UC-3.08 — Order writes Event 1003 on success

**Behavior:** When `New-PACertificate` returns a certificate object, `Invoke-OrderCertificate` writes a `1003 Information` entry to the TU-ACME event log carrying the domain and the new thumbprint, then prints a green confirmation to the operator.

**Given** a prod-initialized TU-ACME where `New-PACertificate` returns a certificate with thumbprint `ABC123`
**When** `Invoke-OrderCertificate` completes successfully
**Then** `Write-EventLogEntry` is called once with `EventId 1003` and a message containing `ABC123`

**Implementation:** `TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1`
**Test:** `tests/Unit/Certificates/UC-3.08.Tests.ps1`
