# UC-6.12 — WebRoot validates WRPath exists and is writable

**Behavior:** Before persisting `WRPath` via `Set-PAPluginArgs`, `Invoke-DnsPluginConfig` resolves the supplied path through `Test-Path -LiteralPath` and a probe write (touch + delete of a `.tu-acme-probe-<guid>` temp file). If either fails, the prompt re-issues with a one-line reason ("path not found" / "path not writable") instead of saving. Empty input re-prompts. Esc cancels the WebRoot flow without saving.

**Given** the operator answers the `WRPath` prompt with a path
**When** validation runs before `Set-PAPluginArgs`
**Then** if `Test-Path -LiteralPath $WRPath` is `$false` the prompt re-issues with "path not found"; if the probe write fails the prompt re-issues with "path not writable"; only when both succeed does `Set-PAPluginArgs -Plugin WebRoot -PluginArgs @{ WRPath = $WRPath }` get called

**Implementation:** `TU-ACME/Private/Certificates/Invoke-DnsPluginConfig.ps1`
**Test:** `tests/Unit/Certificates/UC-6.12.Tests.ps1`
