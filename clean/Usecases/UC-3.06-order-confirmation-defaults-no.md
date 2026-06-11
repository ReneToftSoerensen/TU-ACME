# UC-3.06 — Order confirmation defaults to No

**Behavior:** The final confirmation prompt only proceeds when the operator types a literal `y`. Anything else — empty input, `n`, `yes`, garbage — cancels the order without invoking `New-PACertificate`.

**Given** a prod-initialized TU-ACME with a configured plugin and valid plugin args
**When** the operator types an empty string at the `Proceed? (y/N)` prompt
**Then** the function prints a yellow `Cancelled.` and returns without calling `New-PACertificate`

**Implementation:** `TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1`
**Test:** `tests/Unit/Certificates/UC-3.06.Tests.ps1`
