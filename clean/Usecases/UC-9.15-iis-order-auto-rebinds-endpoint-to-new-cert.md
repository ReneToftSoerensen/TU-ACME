# UC-9.15 — IIS order flow auto-rebinds the originating endpoint to the new cert

## Trigger

`Invoke-IISOrderFromBindings` (UC-9.11) has issued a brand-new cert via
`Invoke-OrderCertificate` and the WebHosting import (UC-9.14) has
succeeded — i.e. a production order driven from one or more IIS site
bindings.

## Behaviour

The IIS thin layer's final step on the success path is to point the
HTTPS binding(s) that supplied the CN / SANs at the freshly issued
certificate. For every binding whose hostname is in the cert's CN+SAN
set:

1. Call `Set-WebBinding -PropertyName 'certificateHash' -Value
   <newThumbprint>` exactly once per binding (UC-9.04).
2. Preserve all other binding settings (host header, port, IP, SNI
   flag) — the only mutation is `certificateHash`.
3. Emit Event 1002 (`IIS binding refreshed with new thumbprint`) per
   updated binding.
4. Per-binding failure is non-fatal: log Event 2001 and continue with
   the next binding (UC-9.03, UC-9.05).

Auto-rebind closes the gap between "new cert exists in the store" and
"IIS actually serves the new cert". Before this UC, an operator who
ordered through the IIS menu would still have to flip back to the
rebind sub-menu and re-pick the cert by hand — defeating the point of
driving the order from the binding inventory.

This UC explicitly does **not** delete the old cert from the store.
Brand-new orders may legitimately coexist with the previous cert
(e.g. the operator added a SAN and wants both certs available during
cutover). Old-cert cleanup is reserved for the renewal flow (UC-9.16).

Dry-run (UC-9.17) skips this step entirely; staging certs never touch
IIS bindings.

**Given** `Invoke-IISOrderFromBindings` has dispatched a successful
production order for CN=`www.fragt.dk` SAN=`api.fragt.dk` derived from
two HTTPS bindings, and the WebHosting import has completed
**When** the IIS thin layer reaches the auto-rebind step
**Then** `Set-WebBinding -PropertyName 'certificateHash' -Value
<newThumbprint>` is called exactly once per originating binding (twice
in total), Event 1002 is emitted per success, and no
`Remove-Item Cert:\LocalMachine\WebHosting\*` call is issued

**Implementation:** `TU-ACME/Private/IIS/Invoke-IISOrderFromBindings.ps1`
**Test:** `tests/Unit/IIS/UC-9.15.Tests.ps1`
