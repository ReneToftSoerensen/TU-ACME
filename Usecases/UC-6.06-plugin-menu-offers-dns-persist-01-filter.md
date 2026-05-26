# UC-6.06 — Plugin menu offers DNS-PERSIST-01 filter

**Behavior:** `Invoke-DnsPluginConfig` exposes DNS-01 persistent plugins as a dedicated bucket. When the operator picks the "DNS-01 (persistent) plugins" first-tier option, the second-tier `Show-Menu` is rendered with only the plugins whose `Get-CurrentPluginType` returns `'dns-01-persist'` (plus a trailing `B. Back`). The bucket is shown even when empty in current Posh-ACME so the operator can tell at a glance that no persist-capable plugins are installed.

**Given** the live `Get-PAPlugin` output mixes DNS-01, DNS-01 persistent, and HTTP-01 plugins
**When** the operator selects "DNS-01 (persistent) plugins" on the first-tier menu
**Then** the second-tier `Show-Menu` is invoked with `-Options` containing only plugins whose challenge type is `dns-01-persist`, followed by `B. Back`

**Implementation:** `TU-ACME/Private/Certificates/Invoke-DnsPluginConfig.ps1`
**Test:** `tests/Unit/Certificates/UC-6.06.Tests.ps1`
