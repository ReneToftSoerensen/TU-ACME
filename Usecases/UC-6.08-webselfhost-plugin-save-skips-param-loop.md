# UC-6.08 — WebSelfHost plugin save skips param loop

**Behavior:** When the operator picks the `WebSelfHost` plugin from the HTTP-01 bucket, `Invoke-DnsPluginConfig` skips the generic parameter loop and confirms the save directly. WebSelfHost has no required PluginArgs (it binds an HttpListener on port 80 to serve `.well-known/acme-challenge/<token>`), so prompting for parameters would only add noise.

**Given** the HTTP-01 plugin list contains `WebSelfHost` and the operator selects it
**When** `Invoke-DnsPluginConfig` resolves the selection
**Then** the generic `Get-PAPlugin -Plugin WebSelfHost -Params` parameter walk is NOT entered, and the save confirmation is reached with an empty PluginArgs hashtable

**Implementation:** `TU-ACME/Private/Certificates/Invoke-DnsPluginConfig.ps1`
**Test:** `tests/Unit/Certificates/UC-6.08.Tests.ps1`
