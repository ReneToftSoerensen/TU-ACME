# UC-5.06 — Dashboard shows empty-state when no certs

**Behavior:** When `Get-PACertificate -List` returns an empty result, the dashboard prints a yellow "No certificates found" message instead of calling `Show-Table` with an empty array.

**Given** `Get-PACertificate -List` returns `@()`
**When** `Invoke-CertificateDashboard` renders its initial frame
**Then** `Write-Host 'No certificates found' -ForegroundColor Yellow` is emitted and `Show-Table` is not invoked for the prod pane

**Implementation:** `TU-ACME/Private/Certificates/Invoke-CertificateDashboard.ps1`
**Test:** `tests/Unit/Certificates/UC-5.06.Tests.ps1`
