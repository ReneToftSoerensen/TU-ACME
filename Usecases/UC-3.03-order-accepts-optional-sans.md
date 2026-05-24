# UC-3.03 — Order accepts an optional SAN list

**Behavior:** The SAN prompt is optional. Empty input means the order contains only the primary domain. A comma-separated list is split and each trimmed value is passed to `New-PACertificate` together with the primary domain.

**Given** a prod-initialized TU-ACME with a configured DNS plugin
**When** the operator types `san1.example.com, san2.example.com` at the SAN prompt
**Then** `New-PACertificate` is called with `-Domain` containing the primary domain plus both SANs

**Implementation:** `TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1`
**Test:** `tests/Unit/Certificates/UC-3.03.Tests.ps1`
