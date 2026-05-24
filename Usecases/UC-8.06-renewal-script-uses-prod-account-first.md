# UC-8.06 — Renewal script calls Use-TUACMEProdAccount before Submit-Renewal

**Behavior:** `Scripts/Invoke-RenewalBackground.ps1` imports the TU-ACME module and the very first Posh-ACME-touching call is `Use-TUACMEProdAccount`. Only after the prod server/account is selected does it call `Submit-Renewal -AllAccounts`.

**Given** the renewal script is run by the scheduled task as SYSTEM
**When** the script enters its `try` block
**Then** `Use-TUACMEProdAccount` is called exactly once before `Submit-Renewal`

**Implementation:** `TU-ACME/Scripts/Invoke-RenewalBackground.ps1`
**Test:** `tests/Scripts/Invoke-RenewalBackground.Tests.ps1`
