# UC-6.02 — DNS plugin prompts mask secret-named parameters

**Behavior:** When prompting for a plugin's parameter values, `Invoke-DnsPluginConfig` uses `Read-Host -AsSecureString` for any parameter whose name matches `(?i)key|password|token|secret`. Non-secret parameter names use a plain `Read-Host`.

**Given** a selected plugin advertises parameters named `ApiKey`, `Token`, and `ServerName`
**When** `Invoke-DnsPluginConfig` walks the param list
**Then** `Read-Host -AsSecureString` is invoked for `ApiKey` and `Token`, and a plain `Read-Host` is invoked for `ServerName`

**Implementation:** `TU-ACME/Private/Certificates/Invoke-DnsPluginConfig.ps1`
**Test:** `tests/Unit/Certificates/UC-6.02.Tests.ps1`
