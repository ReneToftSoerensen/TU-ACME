# UC-9.07 — IIS menu lists every binding (HTTP and HTTPS)

## Trigger

Operator opens the IIS Integration menu (Main menu → 6).

## Behaviour

The menu scans `Get-WebBinding` **without a `-Protocol` filter** and
renders one table row per binding. HTTP-only sites appear alongside
HTTPS sites; the `Protocol` column distinguishes them. The "Rebind a
site" action filters to `Protocol -eq 'https'` rows so the operator
can't pick an HTTP binding for a certificateHash swap.

## Why

The previous menu passed `-Protocol 'https'` and silently dropped every
HTTP binding. On a real IIS box that mixes HTTP redirects, ACME http-01
challenge listeners, and HTTPS sites, the operator needs to see the
full binding inventory in one place — not just the subset that already
has a cert.

## Pester

`tests/Unit/IIS/UC-9.07.Tests.ps1` — case "UC-9.07: renders one row per
binding across HTTP and HTTPS protocols" mocks `Get-WebBinding` to
return a mix of HTTP and HTTPS bindings and asserts the captured table
data contains both protocols and the `Protocol` column is part of the
render-column list.

`tests/Unit/IIS/UC-9.02.Tests.ps1` covers the call-shape guard:
`Get-WebBinding` must be invoked **without** the `Protocol` parameter.
