# UC-9.04: Add HTTPS to an IIS Site (Order-from-Bindings)

## Narrative

As an **operator**, I want to **take an HTTP-only IIS site and provision HTTPS
for it in one flow — choose the CN, optional SANs, and HTTPS port, order the
certificate, import it, and create (or update) the HTTPS binding with the new
cert attached**, so that **I can stand up HTTPS for a site without juggling
`inetmgr`, the ACME order, the PFX import, and the binding by hand**.

This is the previously-**deferred order-from-bindings flow** referenced as
future scope in UC-9.01 (discovery) and UC-9.02 (rebind). It is the post-order
context of the IIS thin-layer flow:

```
IIS HTTP bindings → operator picks a site → choose CN + SANs + HTTPS port
                  → Invoke-OrderCertificate (normal ACME flow, this UC dispatches)
                  → import PFX into Cert:\LocalMachine\WebHosting (this UC)
                  → create/update the HTTPS binding + attach the new thumbprint (this UC)
```

The operator reaches it from the **"Add HTTPS to an IIS site"** menu entry. The
flow lists HTTP bindings (`Get-TUACMEIISBinding | Where-Object Protocol -eq
'http'`), prompts for the HTTPS port (default 443), the CN (pre-filled from the
selected binding's host header when present), optional comma/space-separated
SANs, and whether to dry-run.

Dry-run **never** touches IIS. With `-DryRun`, `Invoke-TUACMEOrderCertificate`
swaps to the staging account in a `try/finally` (UC-3.01); the staging cert is
left in the staging Posh-ACME store and **no import and no binding** happen, so
production IIS state is never touched by a dry-run.

## Acceptance Criteria

- [x] Operator selects an HTTP IIS binding and provisions HTTPS for that site
- [x] Operator chooses the CN (primary domain), optional SANs, and the HTTPS port (default 443)
- [x] The CN prompt is pre-filled with the selected binding's host header when present (Enter accepts it)
- [x] Certificate is ordered via the normal ACME flow (`Invoke-TUACMEOrderCertificate`); event 1003 on success, 3002 on order failure
- [x] Certificate is imported into `Cert:\LocalMachine\WebHosting` (and `My`); event 1011 on import
- [x] HTTPS binding is created at the chosen port/host header, or **updated** if one already exists on that site/port/host
- [x] The new certificate is attached via `Set-WebBinding -PropertyName 'certificateHash'`; event 1002 on success
- [x] SNI (`-SslFlags 1`) is used when a host header is present, else `0`
- [x] Dry-run orders against staging and makes **NO import and NO IIS changes**
- [x] Non-Windows / WebAdministration-unavailable: no binding is attempted; a clear remediation message is surfaced (event 2001 / 3xxx on a genuine binding failure)
- [x] Existing non-cert binding settings are preserved when updating

## Implementation Notes

- Orchestrated by `New-TUACMEIISHttpsBinding` (`TU-ACME/Private/IIS/`) so the
  order→import→bind sequence is unit-testable without prompts.
- Parameter contract: `-SiteName` (mandatory), `-Domain` (mandatory CN),
  `-San` (string[]), `-Port` (default 443), `-HostHeader` (default empty),
  `-DryRun` (switch).
- Domain array is `@($Domain) + $San` de-duped; the first entry is the CN, the
  rest are SANs (matches `Invoke-TUACMEOrderCertificate`).
- The cert **must** live in `Cert:\LocalMachine\WebHosting` before
  `Set-WebBinding` runs; the import targets both `My` and `WebHosting` so the
  binding resolves the thumbprint regardless of store name (UC-9.02).
- The hash is updated before switching `certificateStoreName` to `WebHosting`,
  for the same no-strand rationale as `Update-TUACMEIISBinding`.
- Existing binding detection reuses the `Get-TUACMEIISBinding` selection by
  site + binding information (`*:port:host`) rather than failing on a duplicate.
- Requires admin privileges; the menu entry is admin-gated alongside the other
  IIS actions.
- **Event IDs:** 1003 order success, 1011 import, 1002 binding success;
  3002 order failure, 2001 per-binding failure.
- **Dependency on issue #16:** IIS discovery returns nothing under PowerShell 7
  because WebAdministration is not loaded, so the HTTP-binding list will be
  empty there even with IIS installed. This feature needs #16 resolved, or to
  run under Windows PowerShell 5.1. The flow surfaces this with a clear
  "install IIS Management Scripts and Tools, or run under Windows PowerShell
  5.1" message rather than implying no HTTP sites exist. #16 is **not** fixed
  here.

## Test Coverage

**Unit:** `tests/Unit/IIS/New-TUACMEIISHttpsBinding.Tests.ps1` mocks the order,
`Get-PACertificate`, import, and IIS cmdlets, and verifies: dry-run orders with
`-DryRun` and makes no import/`New-WebBinding`/`Set-WebBinding` calls; the prod
path orders with the CN + SANs, imports into `@('My','WebHosting')`, creates the
binding, attaches the hash, and logs 1002; an existing binding is updated rather
than duplicated; non-Windows / WebAdministration-unavailable makes no binding
calls.

**Integration:** Add HTTPS to a real HTTP site; verify the binding exists and
serves the new cert.

**Scripts:** N/A (operator-initiated menu flow).
