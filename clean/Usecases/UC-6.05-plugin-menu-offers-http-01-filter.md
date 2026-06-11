# UC-6.05 — Plugin menu offers HTTP-01 filter

**Behavior:** `Invoke-DnsPluginConfig` exposes HTTP-01 plugins as a dedicated bucket. When the operator picks the "HTTP-01 plugins" first-tier option, the second-tier `Show-Menu` is rendered with only the plugins whose `Get-CurrentPluginType` returns `'http-01'` (plus a trailing `B. Back`). Operators can therefore see and configure WebRoot / WebSelfHost style plugins without scrolling through DNS plugins.

**Given** the live `Get-PAPlugin` output mixes DNS-01 and HTTP-01 plugins
**When** the operator selects "HTTP-01 plugins" on the first-tier menu
**Then** the second-tier `Show-Menu` is invoked with `-Options` containing only plugins whose challenge type is `http-01`, followed by `B. Back`

**Implementation:** `TU-ACME/Private/Certificates/Invoke-DnsPluginConfig.ps1`
**Test:** `tests/Unit/Certificates/UC-6.05.Tests.ps1`
