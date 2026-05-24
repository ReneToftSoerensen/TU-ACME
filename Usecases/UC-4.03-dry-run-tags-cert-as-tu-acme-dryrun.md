# UC-4.03 — Dry-run tags issued cert as TU-ACME-DryRun

**Behavior:** When the staging order succeeds, `Invoke-DryRunOrder` marks the resulting Posh-ACME order with `FriendlyName = 'TU-ACME-DryRun'` so the certificate dashboard can filter dry-run output out of the prod view. The flow also emits Event 1006 to the Application log so operators can audit dry-run activity.

**Given** `Invoke-DryRunOrder` is running against staging and `New-PACertificate` returns a cert
**When** the order completes successfully
**Then** `Set-PAOrder -FriendlyName 'TU-ACME-DryRun'` is called exactly once, and `Write-EventLogEntry -EventId 1006` is called exactly once

**Implementation:** `TU-ACME/Private/Certificates/Invoke-DryRunOrder.ps1`
**Test:** `tests/Unit/Certificates/UC-4.03.Tests.ps1`
