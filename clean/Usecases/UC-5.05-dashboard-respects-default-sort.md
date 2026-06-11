# UC-5.05 — Dashboard respects DefaultSort config

**Behavior:** The dashboard reads `Dashboard.DefaultSort` from config and applies `Sort-Object NotAfter -Descending` when the value is `ExpiryDescending` (and the corresponding sort for the other supported values).

**Given** `Dashboard.DefaultSort = 'ExpiryDescending'` and three certs with `NotAfter` 30, 10, and 90 days from now
**When** `Invoke-CertificateDashboard` builds the rows passed to `Show-Table`
**Then** the rows are ordered with the latest `NotAfter` first (90, 30, 10)

**Implementation:** `TU-ACME/Private/Certificates/Invoke-CertificateDashboard.ps1`
**Test:** `tests/Unit/Certificates/UC-5.05.Tests.ps1`
