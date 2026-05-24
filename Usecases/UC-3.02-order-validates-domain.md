# UC-3.02 — Order prompts for and validates the primary domain

**Behavior:** `Invoke-OrderCertificate` requires the primary domain to match `^[a-zA-Z0-9.\-*]+$`. Invalid input causes a yellow warning and a re-prompt; no Posh-ACME call happens until a valid domain is supplied.

**Given** a prod-initialized TU-ACME with a configured DNS plugin
**When** the operator types an invalid string at the Domain prompt and then a valid domain
**Then** `Read-Host` is called again after the bad input and `New-PACertificate` is invoked with the valid domain

**Implementation:** `TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1`
**Test:** `tests/Unit/Certificates/UC-3.02.Tests.ps1`
