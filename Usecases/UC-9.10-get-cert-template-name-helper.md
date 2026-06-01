# UC-9.10 — Get-CertTemplateName helper parses AD CS template extensions

## Trigger

Any caller in TU-ACME (currently `Invoke-IISMenu`) needs the AD CS
template name from an `X509Certificate2`.

## Behaviour

`Get-CertTemplateName -Certificate $cert`:
* Returns `''` when `$Certificate` is `$null` or has no `Extensions`
  collection.
* Looks for OID `1.3.6.1.4.1.311.21.7` first (v2 template, modern AD CS).
  On a match it formats the `RawData` via `AsnEncodedData.Format($false)`
  and captures the substring of the resulting `Template=<name>(`
  pattern.
* Falls back to OID `1.3.6.1.4.1.311.20.2` (v1 template, legacy AD CS).
  On a match it formats the `RawData` and returns the first non-empty
  line (stripping a leading `Template=` if present).
* Returns `''` on any parsing failure — never throws — so a malformed
  extension never blocks the rest of the table render.

## Why

Splitting the parse out of `Invoke-IISMenu` keeps the menu file
focused on the table render and gives the parse logic an independent
test surface. Future callers (e.g. a Certificate Dashboard "Template"
column) can use the same helper without duplicating the OID handling.

## Pester

`tests/Unit/Helpers/Get-CertTemplateName.Tests.ps1` — four cases:
* null cert → `''`
* cert with no template extension → `''`
* synthetic v2 extension → non-empty name and no "Major Version Number"
  noise (skipped on hosts whose `AsnEncodedData.Format` doesn't
  pretty-print the MS-specific OID — Linux PS 7)
* garbage v2 RawData → does not throw
