# UC-6.04 — DNS plugin Acme-Dns picks dedicated helper

**Behavior:** When the operator picks the `Acme-Dns` plugin from the configuration menu, `Invoke-DnsPluginConfig` routes to the dedicated `Invoke-AcmeDnsSetup` helper instead of running the generic parameter loop. The Acme-Dns flow needs the CNAME instruction step that the generic loop cannot perform.

**Given** the plugin list contains `Acme-Dns` and the operator selects it
**When** `Invoke-DnsPluginConfig` resolves the selection
**Then** `Invoke-AcmeDnsSetup` is called once and the generic parameter loop (`Get-PAPlugin -Plugin Acme-Dns -Params` walk) is NOT invoked

**Implementation:** `TU-ACME/Private/Certificates/Invoke-DnsPluginConfig.ps1`
**Test:** `tests/Unit/Certificates/UC-6.04.Tests.ps1`
