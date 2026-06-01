# UC-9.09 — IIS table shows AD CS template name on HTTPS rows

## Trigger

Operator opens the IIS Integration menu while at least one HTTPS
binding is configured with a `certificateHash` that resolves to a cert
issued by AD CS (the corporate internal CA that TU-ACME wraps).

## Behaviour

For each HTTPS row whose bound cert resolves in `Cert:\LocalMachine\My`,
the menu calls `Get-CertTemplateName -Certificate $x509` and populates
the `Template` column with the result. Certs without an AD CS template
extension (a non-internal-CA-issued cert that somehow got bound, e.g.
an externally-issued cert) leave the column blank.

## Why

The internal CA issues certs through several templates (WebServer,
WebServer-Custom, ComputerAuth, etc.). Operators triaging "is this
binding using the right template?" otherwise need to crack the cert
open with `Get-ChildItem Cert:\LocalMachine\My\<hash> | fl *` and
hand-parse extensions. Surfacing the template name on the row makes a
fleet-wide template audit a single screen.

The lookup uses two OIDs to stay compatible with both v1 and v2 AD CS
templates:
* `1.3.6.1.4.1.311.21.7` — v2 template (modern: Server 2012+ AD CS).
* `1.3.6.1.4.1.311.20.2` — v1 template (legacy, manually-converted).

For v2 extensions, `AsnEncodedData.Format()` produces a string like
`"Template=WebServer(1.3.6.1.4.1.311.21.8.<x>.<y>), Major Version
Number=100, Minor Version Number=2"`. The helper captures the
human-readable name between `=` and `(`. For v1 extensions, the
formatted string is the template name verbatim.

## Pester

`tests/Unit/IIS/UC-9.07.Tests.ps1` — case "UC-9.09: HTTPS row carries
the AD CS template name from cert extensions" mocks
`Get-CertTemplateName` to return `'WebServer-Custom'` and asserts (a)
the captured row's `Template` is exactly that string, and (b) the menu
actually invoked the helper exactly once for the HTTPS row.

`tests/Unit/Helpers/Get-CertTemplateName.Tests.ps1` — UC-9.10 covers
the helper in isolation: null cert returns `''`, cert without template
extension returns `''`, garbage v2 RawData doesn't throw, and (skipped
on non-Windows hosts) Windows-formatted v2 blobs parse to a non-empty
template name.
