# UC-9.16 — IIS renewal deletes the old cert from WebHosting after rebind

## Trigger

`Update-IISBindingForCert` (UC-9.05) — invoked by the background
renewal script (UC-8.08) — has finished rebinding every HTTPS binding
that was previously pinned to the old thumbprint.

## Behaviour

Renewal is the one IIS flow where the old cert is **known to be stale**
the moment the rebind pass completes. To stop the per-machine store
from growing one entry per renewal cycle, `Update-IISBindingForCert`
finishes with an old-cert cleanup pass:

1. After the rebind loop, check whether **any** HTTPS binding still
   carries `certificateHash = $OldThumbprint`. If a binding rebind
   failed, leave the old cert in place (it's still in use).
2. If no binding still references the old thumbprint, call
   `Remove-Item "Cert:\LocalMachine\WebHosting\$OldThumbprint" -Force`
   exactly once.
3. Emit Event 1002 (or a dedicated cleanup event in the same
   Information band) on success.
4. On failure (cert handle in use, access denied, etc.), log Event
   2001 (Warning) and swallow the exception — renewal is **not** rolled
   back (UC-9.03). The new cert is already serving traffic; a stale
   old cert is harmless until the next sweep.

This cleanup is **renewal-only**. Brand-new orders (UC-9.15) do not
delete any pre-existing cert because the operator may legitimately
want both certs available during cutover. Manual rebinds (UC-9.04) do
not delete anything either; they target a single binding and the
operator may be flipping between two valid certs.

Dry-run never reaches this UC. The renewal script (UC-8.08) only
invokes `Update-IISBindingForCert` for production renewals.

**Given** `Update-IISBindingForCert -OldThumbprint <old>
-NewThumbprint <new>` has finished a rebind pass, every binding now
carries the new thumbprint, and `Cert:\LocalMachine\WebHosting\<old>`
still exists
**When** the helper reaches its cleanup step
**Then** `Remove-Item "Cert:\LocalMachine\WebHosting\<old>" -Force` is
called exactly once and an Information-band event is emitted on
success; if at least one binding still references `<old>` (rebind
partial failure), the `Remove-Item` call is **not** made

**Implementation:** `TU-ACME/Scripts/Posh-ACME-IIS-Plugin.ps1`
(`Update-IISBindingForCert`)
**Test:** `tests/Scripts/Posh-ACME-IIS-Plugin.Tests.ps1` (UC-9.16 cases)
