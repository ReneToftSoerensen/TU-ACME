# UC-5.04 — Dashboard colors certs by expiry

**Behavior:** The dashboard passes a `ColorRule` scriptblock to `Show-Table` that returns `Red` for `DaysLeft <= 0`, `Yellow` for `0 < DaysLeft <= Dashboard.WarnDaysThreshold`, and `Green` otherwise.

**Given** three certs whose `NotAfter` produces `DaysLeft` values of -1 (expired), 10 (within warn window), and 200 (healthy), with `Dashboard.WarnDaysThreshold = 30`
**When** `Invoke-CertificateDashboard` renders the table
**Then** the `ColorRule` argument given to `Show-Table` returns `'Red'`, `'Yellow'`, and `'Green'` for those rows respectively

**Implementation:** `TU-ACME/Private/Certificates/Invoke-CertificateDashboard.ps1`
**Test:** `tests/Unit/Certificates/UC-5.04.Tests.ps1`
