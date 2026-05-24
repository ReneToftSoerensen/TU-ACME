# UC-9.04 — IIS rebind invokes Set-WebBinding with new hash

**Behavior:** Choosing "Rebind a site" from the IIS menu, picking a known site, and selecting a Posh-ACME certificate updates the IIS binding's `certificateHash` to the chosen thumbprint and emits a Windows Event 1002.

**Given** the IIS menu lists at least one HTTPS binding and at least one Posh-ACME certificate
**When** the operator selects "Rebind a site", supplies a known site name, and picks a certificate from the numbered list
**Then** `Set-WebBinding` is called exactly once with `-PropertyName 'certificateHash'` and `-Value <newThumbprint>`, and `Write-EventLogEntry` is called with `EventId 1002`

**Implementation:** `TU-ACME/Private/IIS/Invoke-IISMenu.ps1`
**Test:** `tests/Unit/IIS/UC-9.04.Tests.ps1`
