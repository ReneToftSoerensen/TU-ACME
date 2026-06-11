# UC-6.13 — WebRoot defaults WRPath to IIS site PhysicalPath when invoked from IIS flow

**Behavior:** When `Invoke-DnsPluginConfig` is reached via the IIS Integration menu (UC-9.11 `Invoke-IISOrderFromBindings`) and the operator picks `WebRoot`, the `WRPath` prompt is pre-filled with the selected IIS site's `PhysicalPath`. Pressing Enter accepts the default; typing a different path overrides it. This removes the most common copy-paste step and keeps the manual path entry available for sites whose physical path is not the actual web root (e.g. a virtual directory).

**Given** the operator is in the IIS-driven order flow, has selected an IIS site whose binding maps to a single `PhysicalPath`, and picks `WebRoot` as the HTTP-01 plugin
**When** `Invoke-DnsPluginConfig` issues the `WRPath` prompt
**Then** the prompt shows the site's `PhysicalPath` as the default value, Enter accepts that default, and a non-empty user response overrides it before validation (UC-6.12) runs

**Implementation:** `TU-ACME/Private/Certificates/Invoke-DnsPluginConfig.ps1` (default value passed from `Invoke-IISOrderFromBindings`)
**Test:** `tests/Unit/Certificates/UC-6.13.Tests.ps1`
