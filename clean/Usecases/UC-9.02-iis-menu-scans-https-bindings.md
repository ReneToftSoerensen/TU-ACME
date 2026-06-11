# UC-9.02 — IIS menu scans HTTPS bindings

**Behavior:** The IIS menu enumerates every HTTPS binding on the local IIS host before rendering its table.

**Given** the module is running on Windows with administrator privileges
**When** `Invoke-IISMenu` runs through one render pass and then exits
**Then** `Get-WebBinding -Protocol 'https'` is called exactly once

**Implementation:** `TU-ACME/Private/IIS/Invoke-IISMenu.ps1`
**Test:** `tests/Unit/IIS/UC-9.02.Tests.ps1`
