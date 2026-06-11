# UC-3.04 — Order rejects an unknown DNS plugin

**Behavior:** The plugin name typed at the prompt must match an entry returned by `Get-PAPlugin -List`. Unknown names trigger a yellow warning and a re-prompt; `New-PACertificate` is only called with a known plugin.

**Given** a prod-initialized TU-ACME where `Get-PAPlugin -List` returns `Manual` and `Route53`
**When** the operator types `Bogus` then `Manual` at the DNS plugin prompt
**Then** the flow re-prompts after the bad input and finally calls `New-PACertificate` with `-Plugin Manual`

**Implementation:** `TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1`
**Test:** `tests/Unit/Certificates/UC-3.04.Tests.ps1`
