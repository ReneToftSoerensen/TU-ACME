# UC-9.01 — IIS menu calls Use-TUACMEProdAccount first

**Behavior:** When the IIS menu is entered on a Windows host with administrator rights, the very first TU-ACME action after the admin/platform gate is the prod-account switch. The menu never touches Posh-ACME state before that switch.

**Given** the module is running on Windows with administrator privileges
**When** `Invoke-IISMenu` runs
**Then** `Use-TUACMEProdAccount` is called exactly once before any `Get-WebBinding` or `Get-PACertificate` call

**Implementation:** `TU-ACME/Private/IIS/Invoke-IISMenu.ps1`
**Test:** `tests/Unit/IIS/UC-9.01.Tests.ps1`
