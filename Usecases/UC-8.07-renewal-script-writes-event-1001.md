# UC-8.07 — Renewal script writes Event 1001 per renewed certificate

**Behavior:** The renewal script snapshots `Get-PACertificate -List` thumbprints before and after `Submit-Renewal -AllAccounts`. For every cert whose thumbprint changed, it emits a single `Write-EventLogEntry -EventId 1001 -EntryType Information` describing the subject and the old → new thumbprint.

**Given** one cert's thumbprint differs after `Submit-Renewal`
**When** the renewal loop runs
**Then** `Write-EventLogEntry -EventId 1001` is called exactly once for that cert

**Implementation:** `TU-ACME/Scripts/Invoke-RenewalBackground.ps1`
**Test:** `tests/Scripts/Invoke-RenewalBackground.Tests.ps1`
