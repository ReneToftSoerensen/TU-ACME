# UC-6.03 — DNS plugin save calls Set-PAPluginArgs

**Behavior:** After the operator confirms with `y`, `Invoke-DnsPluginConfig` persists the collected hashtable via `Set-PAPluginArgs -Plugin $name -PluginArgs $hash`. A negative confirmation cancels and `Set-PAPluginArgs` is never called.

**Given** a plugin was selected, the param loop has built a hashtable, and the operator answers `y` to the save prompt
**When** `Invoke-DnsPluginConfig` reaches the save step
**Then** `Set-PAPluginArgs` is called exactly once with `-Plugin` set to the chosen plugin name and `-PluginArgs` set to the collected hashtable

**Implementation:** `TU-ACME/Private/Certificates/Invoke-DnsPluginConfig.ps1`
**Test:** `tests/Unit/Certificates/UC-6.03.Tests.ps1`
