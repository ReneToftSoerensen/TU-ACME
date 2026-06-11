# UC-6.10 — WebSelfHost port-busy failure surfaces operator guidance

**Behavior:** When the WebSelfHost plugin fails because port 80 is held exclusively by another process (e.g. a non-IIS service that does NOT yield the `.well-known/acme-challenge/` URL prefix to HTTP.sys), `Invoke-OrderCertificate` catches the Posh-ACME failure and writes a one-line operator-actionable message naming the conflict and pointing to `netsh http show urlacl` and `Get-NetTCPConnection -LocalPort 80`. Event ID 3xxx is written and the order returns failure without throwing past the menu.

**Given** port 80 is held by a non-IIS listener that does not yield `.well-known/acme-challenge/` to HTTP.sys, and an order is dispatched with `WebSelfHost`
**When** `New-PACertificate` raises the port-busy error
**Then** `Invoke-OrderCertificate` writes a single Cyan/DarkCyan line that names the conflict, suggests `netsh http show urlacl` and `Get-NetTCPConnection -LocalPort 80`, logs Event ID 3xxx, and returns to the menu without an uncaught exception

**Implementation:** `TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1`
**Test:** `tests/Unit/Certificates/UC-6.10.Tests.ps1`
