# UC-5.02 — Dashboard hides dry-run certs by default

**Behavior:** Certificates whose `FriendlyName` equals `TU-ACME-DryRun` are not rendered in the main dashboard table when `Dashboard.ShowDryRunsByDefault = $false`.

**Given** `Get-PACertificate -List` returns a mix of prod certs and certs with `FriendlyName = 'TU-ACME-DryRun'`, and config has `Dashboard.ShowDryRunsByDefault = $false`
**When** `Invoke-CertificateDashboard` is invoked and renders its initial frame
**Then** `Show-Table` is called with `Data` that contains only the prod certs — none of the dry-run rows

**Implementation:** `TU-ACME/Private/Certificates/Invoke-CertificateDashboard.ps1`
**Test:** `tests/Unit/Certificates/UC-5.02.Tests.ps1`
