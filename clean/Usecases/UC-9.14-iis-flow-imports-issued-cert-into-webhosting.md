# UC-9.14 — IIS flow imports issued cert into Cert:\LocalMachine\WebHosting

## Trigger

`Invoke-IISOrderFromBindings` (UC-9.11) has successfully dispatched
`Invoke-OrderCertificate` for a production order, or
`Update-IISBindingForCert` (UC-9.05) is about to rebind one or more
HTTPS bindings to a freshly renewed cert.

## Behaviour

Before any `Set-WebBinding` call, the IIS thin layer ensures the freshly
issued certificate is present in **`Cert:\LocalMachine\WebHosting`**:

1. Resolve the issued cert through Posh-ACME: `Get-PACertificate
   -MainDomain <CN>` → `$cert.PfxFile`, `$cert.PfxPass`, `$cert.Thumbprint`.
2. Check `Test-Path "Cert:\LocalMachine\WebHosting\$($cert.Thumbprint)"`.
3. If missing, call:
   ```powershell
   Import-PfxCertificate `
       -FilePath          $cert.PfxFile `
       -CertStoreLocation 'Cert:\LocalMachine\WebHosting' `
       -Password          (ConvertTo-SecureString $cert.PfxPass -AsPlainText -Force)
   ```
   exactly once.
4. Emit Event 1011 (`Certificate imported into LocalMachine\WebHosting`)
   on success.

`WebHosting` is the IIS-canonical per-machine store. IIS resolves a
binding's `certificateHash` against the local store, and importing into
`WebHosting` (rather than `My`) means the cert is scoped to IIS use,
reducing the chance of it being picked up by unrelated subsystems and
keeping the renewal cleanup (UC-9.16) restricted to one well-defined
store.

A WebHosting import failure is **terminal** for the IIS flow: without
the cert in the per-machine store, `Set-WebBinding` cannot serve it.
The cert is still safely in the Posh-ACME store, so the operator can
retry from the menu. This is the only IIS-flow side effect that
short-circuits the rest of the post-issuance pipeline (UC-9.03).

Dry-run (UC-9.17) skips this step entirely. Staging certs never enter
the per-machine store.

**Given** `Invoke-OrderCertificate` has returned successfully in a
production (non-dry-run) IIS-driven flow and the issued cert's
thumbprint is not present in `Cert:\LocalMachine\WebHosting`
**When** the IIS thin layer transitions from "ACME issuance complete"
to "rebind"
**Then** `Import-PfxCertificate` is called exactly once with
`-CertStoreLocation 'Cert:\LocalMachine\WebHosting'`, Event 1011 is
emitted on success, and the rebind step only runs after this import
returns successfully

**Implementation:** `TU-ACME/Private/IIS/Import-IISCertificate.ps1`
(called by `Invoke-IISOrderFromBindings` and `Update-IISBindingForCert`)
**Test:** `tests/Unit/IIS/UC-9.14.Tests.ps1`
