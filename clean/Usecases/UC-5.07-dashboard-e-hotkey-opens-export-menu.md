# UC-5.07 — Dashboard 'e' hotkey opens Export menu

**Behavior:** Pressing `e` invokes `Invoke-ExportMenu` from the dashboard loop. The function is resolved at runtime via `Get-Command` so the dashboard does not hard-fail when the export module has not yet been wired up.

**Given** the dashboard is open and `Invoke-ExportMenu` is available in the module session
**When** the operator presses `e`
**Then** `Invoke-ExportMenu` is invoked exactly once before the loop continues

**Implementation:** `TU-ACME/Private/Certificates/Invoke-CertificateDashboard.ps1`
**Test:** `tests/Unit/Certificates/UC-5.07.Tests.ps1`
