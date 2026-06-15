# UC-9.02: IIS Binding Update (Post-Issuance & Manual)

## Narrative

As an **automated system and operator**, I want **every IIS HTTPS binding that previously served the old certificate to be re-pointed at the freshly issued certificate**, so that **the IIS endpoint actually serves the new cert immediately after an order or renewal — without me having to crack open `inetmgr`**.

The rebind step is the **last leg of the IIS thin-layer flow**:

```
IIS bindings → derive CN + SANs → Invoke-OrderCertificate (normal ACME flow)
            → import PFX into Cert:\LocalMachine\WebHosting (this UC)
            → rebind every matching binding to the new thumbprint (this UC)
            → on renewal: delete the old cert from the store (UC-9.03)
```

A rebind is triggered in three contexts:

1. **Post-order** — an order-from-bindings flow (future scope) would update the binding the operator started from to the new thumbprint.
2. **Post-renewal** — the background renewal script (UC-7.02) walks every binding whose `certificateHash` equals the renewed cert's old thumbprint and updates each one (this UC).
3. **Manual** — the "Rebind IIS site" menu entry (this UC) lets the operator point any HTTPS binding at any cert currently in the Posh-ACME store.

Dry-run **never** rebinds. When the IIS flow runs with `-DryRun` (UC-3.01), the issued staging cert is left in the staging Posh-ACME store and IIS state is untouched.

## Acceptance Criteria

- [x] Rebind operation updates the binding's `certificateHash` to the new thumbprint
- [x] Binding is updated in IIS configuration via `Set-WebBinding -PropertyName 'certificateHash'` (this UC)
- [x] Rebind happens automatically after a non-dry-run IIS-driven order or renewal
- [x] Rebind is **skipped** entirely when the operation is a dry-run
- [x] Event Log entry ID 1002 is written on success
- [x] Manual rebind is also reachable from the IIS menu and works against any cert in the Posh-ACME store
- [x] Multiple bindings sharing the old thumbprint are updated in a single pass (this UC)
- [x] All non-cert binding settings (host header, port, SNI flag) are preserved

## Implementation Notes

- Rebind via `Set-WebBinding -PropertyName 'certificateHash' -Value <newThumbprint>` (this UC)
- Requires admin privileges
- Post-issuance: an order-from-bindings flow (future scope) would rebind after `Invoke-OrderCertificate` returns and the WebHosting import succeeds
- Post-renewal: triggered by `Update-TUACMEIISBinding` from the background renewal script (UC-7.02, this UC)
- The cert **must** already live in `Cert:\LocalMachine\WebHosting` before `Set-WebBinding` runs (IIS reads the binding's cert from a per-machine store; WebHosting is the IIS-canonical one)

## Test Coverage

**Unit:** Mock `Set-WebBinding` and IIS state; verify thumbprint update, that dry-run takes the no-rebind path, and that the rebind only fires after the WebHosting import.

**Integration:** Update a binding; verify thumbprint changes in IIS and the site serves the new cert.

**Scripts:** Renewal script calls rebind after import (UC-7.02).
