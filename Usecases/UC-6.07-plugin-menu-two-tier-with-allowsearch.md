# UC-6.07 — Plugin menu uses two-tier flow with AllowSearch

**Behavior:** `Invoke-DnsPluginConfig` no longer renders ~100 plugins in a single flat `Show-Menu`. Instead the first tier presents three challenge-type buckets (DNS-01, DNS-01 persistent, HTTP-01) plus `B. Back`, and the second tier presents the plugins in the chosen bucket. The second-tier `Show-Menu` call passes `-AllowSearch` so the operator can type `/` to filter the long list by typing a substring of the plugin name.

**Given** the live `Get-PAPlugin` output contains many plugins
**When** the operator opens the plugin configuration submenu and picks any challenge-type bucket
**Then** the first `Show-Menu` invocation has exactly four options (the three challenge-type buckets + `B. Back`), and the second `Show-Menu` invocation is made with the `-AllowSearch` switch set

**Implementation:** `TU-ACME/Private/Certificates/Invoke-DnsPluginConfig.ps1`
**Test:** `tests/Unit/Certificates/UC-6.07.Tests.ps1`
