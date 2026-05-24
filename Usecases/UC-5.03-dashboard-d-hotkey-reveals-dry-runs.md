# UC-5.03 — Dashboard 'd' hotkey reveals dry-runs pane

**Behavior:** Pressing `d` toggles a second `Show-Table` pane below the main table containing certificates whose `FriendlyName` equals `TU-ACME-DryRun`.

**Given** the dashboard is open with `ShowDryRunsByDefault = $false` and at least one dry-run cert exists
**When** the operator presses `d` and the loop re-renders
**Then** `Show-Table` is invoked twice on the next iteration — once for the prod rows, once for the dry-run rows

**Implementation:** `TU-ACME/Private/Certificates/Invoke-CertificateDashboard.ps1`
**Test:** `tests/Unit/Certificates/UC-5.03.Tests.ps1`
