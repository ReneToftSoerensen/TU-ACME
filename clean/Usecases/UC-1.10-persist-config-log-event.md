# UC-1.10 — Persist config and log Event 1010

**Behavior:** After both accounts are created, the wizard persists the URLs, email, account IDs, and `Initialized = $true` with `InitializedAt` to `config.json` and emits Windows Event Log entry 1010.

**Given** the wizard has created both prod and staging accounts
**When** the wizard reaches its persistence step
**Then** `Set-TUACMEConfig` is called once with `Initialized = $true`, all URLs/email/IDs filled, and `Write-EventLogEntry -EventId 1010 -EntryType Information` is called once

**Implementation:** `TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1`
**Test:** `tests/Unit/Bootstrap/UC-1.10.Tests.ps1`
