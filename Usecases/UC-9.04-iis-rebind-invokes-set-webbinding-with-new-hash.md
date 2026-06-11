# UC-9.04 — IIS rebind invokes Set-WebBinding with new hash

**Behavior:** Choosing "Rebind a site" from the IIS menu, picking a known site, and selecting a Posh-ACME certificate updates the IIS binding's `certificateHash` to the chosen thumbprint and emits a Windows Event 1002.

Before `Set-WebBinding` runs, the menu confirms the chosen cert is present in `Cert:\LocalMachine\WebHosting`. If it is not (i.e. the cert lives only in the Posh-ACME store but has never been imported), the menu imports the PFX into `WebHosting` first (UC-9.14) and only then issues the rebind. This guarantees the per-machine cert store always carries the thumbprint IIS is being pointed at.

The same rebind primitive is reused by:

* The IIS order flow (UC-9.11, UC-9.15) — after a brand-new cert is issued, the originating binding is rebound to the new thumbprint as the final step of the thin-layer pipeline.
* The renewal script (UC-8.08) via `Update-IISBindingForCert` (UC-9.05) — every binding pinned to the old thumbprint is updated, then the old cert is deleted (UC-9.16).

Dry-run (UC-9.17) does **not** invoke this primitive; staging certs never touch IIS bindings.

**Given** the IIS menu lists at least one HTTPS binding and at least one Posh-ACME certificate
**When** the operator selects "Rebind a site", supplies a known site name, and picks a certificate from the numbered list
**Then** the cert is ensured to be present in `Cert:\LocalMachine\WebHosting`, `Set-WebBinding` is called exactly once with `-PropertyName 'certificateHash'` and `-Value <newThumbprint>`, and `Write-EventLogEntry` is called with `EventId 1002`

**Implementation:** `TU-ACME/Private/IIS/Invoke-IISMenu.ps1`
**Test:** `tests/Unit/IIS/UC-9.04.Tests.ps1`
