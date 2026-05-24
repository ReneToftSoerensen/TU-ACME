# `Set-PAOrder -NewKey` is the post-leak key-rotation primitive

**Symptom**: User asks "how do I force-renew with a fresh private key after a leak?" — `Submit-Renewal` reuses the existing key by default.
**Discovered**: 2026-05-22 while implementing the dashboard's `[F] Force renew (new key)` action
**Affects**: Posh-ACME 4.x

## What broke
`Submit-Renewal` has `-Force` (skip the renewal-window check) but no `-NewKey` flag. Calling it after a private key leak therefore reuses the compromised key on the new cert.

## Root cause
Key rotation is a *property of the order*, not of the renewal call. Posh-ACME exposes this via `Set-PAOrder -NewKey` — a flag that says "next time you renew this order, generate a fresh private key first".

## Fix
Two-step force-renew:

```powershell
Set-PAOrder -MainDomain $domain -NewKey
Submit-Renewal -MainDomain $domain -Force
```

Implemented as `_Invoke-TUACMEForceRenew` in `Invoke-CertificateDashboard.ps1`. When MainDomain is empty (internal-CA case), use `Set-PAOrder -Name <folder-name>` and `Submit-Renewal -Force` (no MainDomain filter — renews the active order).

Don't try to combine into Submit-Renewal — `-NewKey` is not a Submit-Renewal parameter.

## See also
- `posh-acme-no-set-paconfig.md`
- `posh-acme-revoke-vs-delete.md`
