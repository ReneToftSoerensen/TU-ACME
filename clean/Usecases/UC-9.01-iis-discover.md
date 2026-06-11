# UC-9.01: IIS Binding Discovery

## Narrative

As an **operator**, I want to **see all IIS HTTPS bindings and their current certificates**, so that **I can map certificates to bindings and plan renewals**.

## Acceptance Criteria

- [ ] Certificate dashboard displays all IIS HTTPS bindings (site name, host header, thumbprint)
- [ ] Bindings are linked to certificates in the TU-ACME store
- [ ] Current certificate expiry is displayed next to each binding
- [ ] Bindings without a valid certificate are highlighted or marked
- [ ] Discovery works on IIS 7.5+ (Server 2008 R2+)
- [ ] Dashboard is keyboard-navigable and read-only

## Implementation Notes

- IIS discovery via `Get-WebBinding` (WebAdministration module)
- Binding info: site name, host header, binding information, thumbprint
- Thumbprint matched to TU-ACME store for expiry and details

## Test Coverage

**Unit:** Mock IIS bindings and cert lookup; verify display logic.

**Integration:** Run on a system with IIS installed; verify bindings and certs appear.

**Scripts:** N/A
