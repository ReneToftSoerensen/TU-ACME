# Revoke vs Delete are independent operations

**Symptom**: User assumes `[D] Delete (local)` revokes the cert at the ACME server, or that revoking also removes local files. Neither is true.
**Discovered**: 2026-05-22 designing the dashboard detail-view actions
**Affects**: Posh-ACME 4.x

## What broke
A leaked private key needs *both*:

1. Revocation at the ACME server (so anyone who got the leaked key can't use the cert anymore — browsers will reject it once they pick up the new CRL/OCSP).
2. Local removal of the on-disk cert + key (so this machine doesn't accidentally keep serving it).

Bundling the two confused the user about what was happening.

## Fix
Two separate dashboard actions:

- **`[V] Revoke`** → `Revoke-PACertificate -MainDomain $X -Force` (with `-Name` fallback for empty MainDomain). Sends revocation request to the ACME server. Local files stay. Logs EventId 1004.
- **`[D] Delete`** → `_Remove-TUACMECertDir` wipes the local folder. Server-side cert is unaffected. Logs EventId 1003.

Help text in the revoke prompt explicitly tells the user "The local files remain — use [D] Delete separately if you also want to purge."

Wrapped both in TU-ACME helper functions (`_Invoke-TUACMERevoke`, `_Remove-TUACMECertDir`) so tests can mock without touching Posh-ACME cmdlets through our logging proxies — see `pester-mock-proxy-fails.md`.

## See also
- `posh-acme-no-remove-pacertificate.md`
- `posh-acme-set-paorder-newkey.md`
- `pester-mock-proxy-fails.md`
