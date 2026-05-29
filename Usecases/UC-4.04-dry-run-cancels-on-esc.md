# UC-4.04 — Dry-run cancels and restores prod when Esc is pressed at any prompt

**Behavior:** `Invoke-DryRunOrder` reads each interactive prompt (domain, SANs, plugin, confirmation) via `Read-LineOrEscape`. If the operator presses Escape at any of them, the function prints `Cancelled (Esc).` and returns without calling `New-PACertificate` and without writing Event 1006. The `finally` block still runs, so `Use-TUACMEProdAccount` is called and the active Posh-ACME account is restored to prod.

**Given** an initialized TU-ACME and the operator runs `Invoke-DryRunOrder`
**When** the operator presses Esc at the domain, SANs, plugin, or confirmation prompt
**Then** the function returns; `New-PACertificate` is never invoked; `Write-EventLogEntry -EventId 1006` is never called; `Use-TUACMEProdAccount` is invoked from the `finally` so the session ends pointed at prod

**Implementation:** `TU-ACME/Private/Certificates/Invoke-DryRunOrder.ps1`
**Test:** `tests/Unit/Certificates/UC-4.04.Tests.ps1`
