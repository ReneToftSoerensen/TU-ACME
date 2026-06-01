# UC-9.08 — IIS table shows certificate expiry on HTTPS rows

## Trigger

Operator opens the IIS Integration menu while at least one HTTPS
binding is configured with a `certificateHash` that resolves to a cert
present in `Cert:\LocalMachine\My`.

## Behaviour

For each HTTPS row, the menu looks the bound cert up by thumbprint in
`Cert:\LocalMachine\My` and populates the `Expires` column with
`NotAfter` formatted as `yyyy-MM-dd`. HTTP rows leave the column
blank. Cert lookups within a single render pass are cached so a cert
bound to several sites is only fetched once.

If the cert is not present in the local store (uncommon — IIS won't
serve TLS without the cert installed, but the binding row can outlive
the cert), `Expires` stays blank rather than throwing.

## Why

The most operationally useful piece of information about a TLS binding
isn't the cert subject (already on the row) — it's how soon the cert
expires. Surfacing it in the inventory table means the operator can
scan three sites at once instead of opening certlm.msc per site.

## Pester

`tests/Unit/IIS/UC-9.07.Tests.ps1` — case "UC-9.08: HTTPS row carries
the NotAfter date from the LocalMachine\My cert" stubs `Test-Path` /
`Get-Item` to return a fake cert with `NotAfter = 2027-04-15` and
asserts the captured row's `Expires` is exactly `'2027-04-15'`.
