# UC-9.06 — IIS rebind picker lists sites with their distinct hostnames

**Behavior:** When the operator picks "1. Rebind a site" in `Invoke-IISMenu`, the function does not ask for a site name as free text. Instead it calls `Show-Menu` with one option per HTTPS binding, labeled `<site> - <hostname>` where `<hostname>` is the third colon-separated segment of `bindingInformation`. Catch-all bindings (empty hostname) render as `<site> - <no hostname>`. Sites with multiple bindings appear once per binding so the operator can disambiguate. The picker is invoked with `-AllowSearch` so `/` filters the list. Picking `B. Back` (or pressing Esc) returns to the outer IIS menu without performing a rebind.

**Given** the IIS menu has scanned a set of HTTPS bindings
**When** the operator picks "Rebind a site"
**Then** `Show-Menu` is invoked with one option per binding labeled `<site> - <hostname>`, plus a trailing `B. Back` entry, and `-AllowSearch` is enabled

**Implementation:** `TU-ACME/Private/IIS/Invoke-IISMenu.ps1`
**Test:** `tests/Unit/IIS/UC-9.06.Tests.ps1`
