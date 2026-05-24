# UC-3.05 — Order aborts when plugin args are missing

**Behavior:** Posh-ACME plugin credentials are configured separately. If `Get-PAPluginArgs <plugin>` returns nothing, `Invoke-OrderCertificate` prints a yellow note pointing the operator at the DNS Plugins menu and returns without calling `New-PACertificate`.

**Given** a prod-initialized TU-ACME where `Get-PAPluginArgs` returns `$null`
**When** `Invoke-OrderCertificate` reaches the plugin-args resolution step
**Then** the function returns without invoking `New-PACertificate`

**Implementation:** `TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1`
**Test:** `tests/Unit/Certificates/UC-3.05.Tests.ps1`
