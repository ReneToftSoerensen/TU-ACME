# UC-9.03 — IIS menu joins bindings to certs by thumbprint

**Behavior:** For each HTTPS binding, the menu looks up the matching Posh-ACME certificate by comparing the binding's `certificateHash` to each certificate's `Thumbprint`. The matching certificate's `Subject` is rendered in the `CertSubject` column.

**Given** an HTTPS binding whose `certificateHash` matches the `Thumbprint` of a known Posh-ACME certificate
**When** `Invoke-IISMenu` renders the binding table
**Then** the row for that binding is passed to `Show-Table` with `CertSubject` equal to the matching certificate's `Subject`

**Implementation:** `TU-ACME/Private/IIS/Invoke-IISMenu.ps1`
**Test:** `tests/Unit/IIS/UC-9.03.Tests.ps1`
