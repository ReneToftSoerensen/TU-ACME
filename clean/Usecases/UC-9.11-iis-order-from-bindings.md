# UC-9.11 — IIS menu can order new certs from site bindings

## Trigger

Operator opens the IIS Integration menu and picks
**"2. Order new cert from site bindings"** — typically the natural
follow-up to seeing "No Posh-ACME certificates available" in the rebind
flow on a freshly-deployed host.

## Behaviour

1. Scan every binding via `Get-WebBinding` (no protocol filter so
   HTTP-only sites are reachable from this flow too).
2. Group by site name extracted from `ItemXPath` and present a numeric
   list. Operator types a comma-separated index list, or `all`, or
   presses Esc to cancel.
3. Collect every distinct hostname across the chosen sites' bindings,
   skipping empty / catch-all entries.
4. Run `Test-IsFqdnHostname` on each hostname. FQDN-shaped names get an
   `[ok]` marker; single-label / IP-literal / underscored / mis-wildcarded
   names get a `[WARN]` marker and a one-line explanation about internal
   CA acceptance. Warnings are advisory — the operator can continue.
5. If more than one hostname survived, ask whether to **bundle** all
   names into one cert (SANs) or **split** into one cert per hostname.
6. Dispatch by calling `Invoke-OrderCertificate -Domain <primary> -Sans
   <rest>` — the existing plugin / plugin-args / summary / confirmation
   flow runs unchanged. Bundle=Yes ⇒ one order. Bundle=No ⇒ one order
   per hostname in sequence.

## Why

Before this UC, the only way to produce a new cert was the top-level
"Order new certificate" entry, which prompted for the primary domain
and SANs as free text. On a fresh deploy with three or four IIS sites,
the operator had to retype every hostname from memory or by cross-
referencing `inetmgr`. Driving the order from the actual binding
inventory removes that copy-paste step and surfaces "wrong" hostnames
(single-label NetBIOS names) **before** the order hits the CA.

The non-FQDN warning is advisory rather than a block because TU-ACME
wraps an **internal corporate CA**. Public CAs reject single-label names
out of hand; internal AD CS deployments routinely accept them, and
some sites genuinely use that shape on purpose.

`Invoke-OrderCertificate` was extended with optional `-Domain` and
`-Sans` parameters so the IIS-side flow can dispatch without
reimplementing the order logic. When either parameter is supplied the
corresponding prompt is skipped; plugin selection, plugin-args
resolution, summary, and confirmation still run.

## Pester

`tests/Unit/IIS/UC-9.11.Tests.ps1` — four cases:

* `bundle=Yes`: 5 hostnames across 3 sites collapse to one
  `Invoke-OrderCertificate` call whose Domain is the first hostname
  and Sans contains the other four.
* `bundle=No`: 5 hostnames produce 5 separate calls, each with Sans
  count = 0 and the Domain set sorted equals the input set.
* Esc on the site picker calls `Invoke-OrderCertificate` zero times.
* A binding fixture made entirely of single-label hostnames still
  reaches one `Invoke-OrderCertificate` call (warn-but-allow contract).
