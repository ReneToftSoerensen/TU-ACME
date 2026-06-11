# UC-6.11 — WebRoot plugin prompts for WRPath

**Behavior:** When the operator picks the `WebRoot` plugin from the HTTP-01 bucket, `Invoke-DnsPluginConfig` enters a single-parameter prompt loop that asks for `WRPath` (the local filesystem path that maps to `http://<domain>/` on the target web server). The value is the only PluginArg WebRoot requires; the param loop ends as soon as `WRPath` is supplied or the operator cancels with Esc.

**Given** the HTTP-01 plugin list contains `WebRoot` and the operator selects it
**When** `Invoke-DnsPluginConfig` resolves the selection
**Then** a single `Read-LineOrEscape` prompt labelled `WRPath` is issued, and the collected hashtable contains exactly one key (`WRPath`) before the save confirmation step

**Implementation:** `TU-ACME/Private/Certificates/Invoke-DnsPluginConfig.ps1`
**Test:** `tests/Unit/Certificates/UC-6.11.Tests.ps1`
