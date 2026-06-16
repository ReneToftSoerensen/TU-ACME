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
- [x] The new certificate is attached via the session's IIS provider — `Set-WebBinding -PropertyName 'certificateHash'` on 5.1, `Set-TUACMEIISBindingCertificate` (ServerManager) on PowerShell 7; event 1002 on success
- [x] SNI (`-SslFlags 1`) is used when a host header is present, else `0`
- [x] Dry-run orders against staging and makes **NO import and NO IIS changes**
- [x] Non-Windows / no IIS provider available: no binding is attempted; a clear remediation message is surfaced (event 2001 / 3xxx on a genuine binding failure)
- [x] Existing non-cert binding settings are preserved when updating

## Implementation Notes

- Orchestrated by `New-TUACMEIISHttpsBinding` (`TU-ACME/Private/IIS/`) so the
  order→import→bind sequence is unit-testable without prompts.
- Parameter contract: `-SiteName` (mandatory), `-Domain` (mandatory CN),
  `-San` (string[]), `-Port` (default 443), `-HostHeader` (default empty),
  `-DryRun` (switch).
- Domain array is `@($Domain) + $San` de-duped; the first entry is the CN, the
  rest are SANs (matches `Invoke-TUACMEOrderCertificate`).
- The binding is provisioned through the session's IIS provider, selected by
  `Get-TUACMEIISProvider` (issue #16): WebAdministration `New-WebBinding` +
  `Set-WebBinding` on Windows PowerShell 5.1, and the IISAdministration
  `Microsoft.Web.Administration` ServerManager
  (`Get-IISServerManager`, `$site.Bindings.Add($bindingInformation, 'https')`,
  `SetAttributeValue('sslFlags', …)`, `CommitChanges()`) on PowerShell 7. The
  PowerShell 7 cert-attach step reuses `Set-TUACMEIISBindingCertificate`
  (the same helper UC-9.02 rebind uses).
- The cert **must** live in `Cert:\LocalMachine\WebHosting` before the cert is
  attached; the import targets both `My` and `WebHosting` so the binding
  resolves the thumbprint regardless of store name (UC-9.02).
- On the 5.1 path the hash is updated before switching `certificateStoreName`
  to `WebHosting`, for the same no-strand rationale as `Update-TUACMEIISBinding`;
  on PowerShell 7 `Set-TUACMEIISBindingCertificate` sets both atomically and
  commits.
- Existing binding detection reuses the `Get-TUACMEIISBinding` selection by
  site + binding information (`*:port:host`) rather than failing on a duplicate.
- Requires admin privileges; the menu entry is admin-gated alongside the other
  IIS actions.
- **Event IDs:** 1003 order success, 1011 import, 1002 binding success;
  3002 order failure, 2001 per-binding failure.
- **Built on issue #16:** the flow uses the #16 provider abstraction
  (`Get-TUACMEIISProvider`) for both discovery and binding provisioning, so it
  now works under **both** Windows PowerShell 5.1 (WebAdministration) and
  PowerShell 7 (IISAdministration) wherever an IIS provider is present. When no
  provider is available it surfaces a clear "install IIS Management Scripts and
  Tools, or run under Windows PowerShell 5.1" message rather than implying no
  HTTP sites exist.

## Test Coverage

**Unit:** `tests/Unit/IIS/New-TUACMEIISHttpsBinding.Tests.ps1` mocks the order,
`Get-PACertificate`, import, and IIS cmdlets, and verifies: dry-run orders with
`-DryRun` and makes no import/`New-WebBinding`/`Set-WebBinding` calls; the prod
path orders with the CN + SANs, imports into `@('My','WebHosting')`, creates the
binding, attaches the hash, and logs 1002; an existing binding is updated rather
than duplicated; non-Windows / no-provider makes no binding calls. The
IISAdministration path is covered too (provider mocked to `'IISAdministration'`):
the binding is created via a mocked `Get-IISServerManager` ServerManager and the
cert attached via `Set-TUACMEIISBindingCertificate` (no `New-WebBinding`/
`Set-WebBinding`), with an existing-binding case asserting no ServerManager
`Add`.

**Integration:** Add HTTPS to a real HTTP site; verify the binding exists and
serves the new cert.

**Scripts:** N/A (operator-initiated menu flow).
