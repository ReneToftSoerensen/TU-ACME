# UC-9.01: IIS Binding Discovery

## Narrative

As an **operator**, I want to **see all IIS bindings (HTTP and HTTPS) and the certificate behind each HTTPS binding**, so that **I can map certificates to bindings, drive an order from the binding inventory, and plan renewals — without retyping hostnames from `inetmgr`**.

The IIS menu is the **thin layer** at the top of every IIS flow. It does **not** reimplement ACME orders, account selection, or certificate issuance. Its job is:

1. **Enumerate** bindings via the available IIS provider (no protocol filter — HTTP rows are listed too): `Get-WebBinding` (WebAdministration) on Windows PowerShell 5.1, `Get-IISSite` (IISAdministration) on PowerShell 7, since WebAdministration is unreliable under PowerShell 7 (issue #16).
2. **Project** each HTTPS row with its certificate's subject, expiry, and AD CS template.
3. **Derive** the CN (primary domain) and SANs (additional hostnames) from selected site bindings when the operator chooses to order.
4. **Dispatch** to the normal ACME flow (`Invoke-OrderCertificate`) — bootstrap, plugin selection, plugin args, summary, confirmation, `New-PACertificate` all run unchanged.

Dry-run is supported through the same dispatch: when the IIS order flow is entered with `-DryRun`, `Invoke-OrderCertificate` swaps to the staging account in a `try/finally` (UC-3.01) and the post-issuance store import and rebind steps are **skipped** so production IIS state is never touched by a dry-run.

## Acceptance Criteria

- [x] Certificate dashboard displays all IIS bindings (site name, host header, protocol, thumbprint on HTTPS rows)
- [x] HTTPS bindings are linked to certificates in `Cert:\LocalMachine\WebHosting` (primary) and `Cert:\LocalMachine\My` (fallback) by thumbprint
- [x] Current certificate `NotAfter` is displayed next to each HTTPS binding
- [x] AD CS template name is displayed next to each HTTPS binding
- [x] Bindings without a resolvable certificate leave `Expires` / `Template` blank rather than throwing
- [ ] Discovery works on IIS 7.5+ (Server 2008 R2+)
- [ ] Dashboard is keyboard-navigable; the menu also exposes the manual rebind action (UC-9.02). An order-from-bindings flow remains future scope.

## Implementation Notes

- `Get-TUACMEIISProvider` picks the IIS provider per edition: `IISAdministration` (`Get-IISSite`) on PowerShell 7, `WebAdministration` (`Get-WebBinding`) on Windows PowerShell 5.1; no `-Protocol` filter on either path
- When neither provider is available, discovery returns empty and the Rebind / Clean-up handlers report "IIS management is unavailable" (via `Test-TUACMEIISAvailable`) instead of a misleading "No HTTPS bindings found" (issue #16)
- Binding info: site name, host header, binding information, protocol, thumbprint
- Thumbprint resolved via `Cert:\LocalMachine\WebHosting` first, then `Cert:\LocalMachine\My`
- The menu is read-only; mutating actions (order, rebind) are explicit sub-flows
- CN/SAN derivation for an order-from-bindings flow is future scope, not part of the discovery render

## Test Coverage

**Unit:** Mock IIS bindings and cert lookup; verify display logic and the WebHosting → My fallback.

**Integration:** Run on a system with IIS installed; verify bindings and certs appear.

**Scripts:** N/A
