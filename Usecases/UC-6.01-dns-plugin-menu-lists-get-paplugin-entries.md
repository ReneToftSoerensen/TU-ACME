# UC-6.01 — DNS plugin menu lists Get-PAPlugin entries

**Behavior:** `Invoke-DnsPluginConfig` renders a `Show-Menu` whose options are derived from the live `Get-PAPlugin` output, so adding a plugin to Posh-ACME exposes it in TU-ACME without code changes.

**Given** an initialized TU-ACME and a non-empty Posh-ACME plugin list
**When** `Invoke-DnsPluginConfig` is invoked
**Then** `Show-Menu` is called once with `-Options` matching the plugin names returned by `Get-PAPlugin` (plus a trailing `B. Back`)

**Implementation:** `TU-ACME/Private/Certificates/Invoke-DnsPluginConfig.ps1`
**Test:** `tests/Unit/Certificates/UC-6.01.Tests.ps1`
