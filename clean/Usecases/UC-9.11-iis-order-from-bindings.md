# UC-9.11 — IIS menu can order new certs from site bindings

## Trigger

Operator opens the IIS Integration menu and picks
**"2. Order new cert from site bindings"** — typically the natural
follow-up to seeing "No Posh-ACME certificates available" in the rebind
flow on a freshly-deployed host.

## Behaviour

`Invoke-IISOrderFromBindings` is the **thin layer** that turns "the IIS
bindings on this host" into "a CN and a SAN list" and then **dispatches
to the normal ACME flow**. It does not call `Set-PAAccount`,
`Set-PAServer`, `New-PAOrder`, `New-PACertificate`, or any other
Posh-ACME primitive directly — every certificate operation flows
through `Invoke-OrderCertificate` (UC-3.01..UC-3.09) which in turn is
the only path that talks to Posh-ACME.

End-to-end:

1. **Discover** — Scan every binding via `Get-WebBinding` (no protocol
   filter so HTTP-only sites are reachable from this flow too).
2. **Group** — by site name extracted from `ItemXPath`; present a numeric
   list. Operator types a comma-separated index list, or `all`, or
   presses Esc to cancel.
3. **Derive CN and SANs** — Collect every distinct hostname across the
   chosen sites' bindings, skipping empty / catch-all entries. The first
   surviving hostname is the **CN (primary domain)**; the rest become
   **SANs**.
4. **Validate** — Run `Test-IsFqdnHostname` on each hostname (UC-9.12).
   FQDN-shaped names get an `[ok]` marker; single-label / IP-literal /
   underscored / mis-wildcarded names get a `[WARN]` marker and a
   one-line explanation about internal CA acceptance. Warnings are
   advisory — the operator can continue.
5. **Bundle or split** — If more than one hostname survived, ask whether
   to **bundle** all names into one cert (SANs) or **split** into one
   cert per hostname.
6. **Pick challenge type** — Ask DNS-01 vs HTTP-01 once (UC-9.13) and
   thread it through to every dispatched order.
7. **Dispatch to normal ACME flow** — Call
   `Invoke-OrderCertificate -Domain <CN> -Sans <rest>
   -ChallengeType <type> [-DryRun]`. The existing plugin /
   plugin-args / summary / confirmation flow runs unchanged. Bundle=Yes
   ⇒ one order. Bundle=No ⇒ one order per hostname in sequence.
8. **Post-issuance (production only)** — After
   `Invoke-OrderCertificate` returns successfully, the IIS thin layer:
   * Imports the issued cert into `Cert:\LocalMachine\WebHosting`
     (UC-9.14).
   * Rebinds the originating IIS binding to the new thumbprint
     (UC-9.15, UC-9.04).
   * Does **not** delete any old cert — this is a brand new order, not
     a renewal. Old-cert cleanup is the renewal flow's responsibility
     (UC-9.16).
9. **Post-issuance (dry-run)** — When `-DryRun` is supplied (UC-9.17),
   steps 8a and 8b are **skipped entirely**: the staging cert lives
   only in the Posh-ACME staging store, IIS state is untouched, and
   production is restored by `Invoke-OrderCertificate`'s try/finally
   (UC-3.01).

## Why

Before this UC, the only way to produce a new cert was the top-level
"Order new certificate" entry, which prompted for the primary domain
and SANs as free text. On a fresh deploy with three or four IIS sites,
the operator had to retype every hostname from memory or by cross-
referencing `inetmgr`. Driving the order from the actual binding
inventory removes that copy-paste step and surfaces "wrong" hostnames
(single-label NetBIOS names) **before** the order hits the CA.

Keeping the flow as a thin layer over `Invoke-OrderCertificate` means
the IIS-specific code stays small: it derives CN+SANs, it imports +
rebinds at the end, and that is all. Every account / server / order /
challenge / plugin concern is owned by the normal ACME flow.

The non-FQDN warning is advisory rather than a block because TU-ACME
wraps an **internal corporate CA**. Public CAs reject single-label names
out of hand; internal AD CS deployments routinely accept them, and
some sites genuinely use that shape on purpose.

`Invoke-OrderCertificate` was extended with optional `-Domain`,
`-Sans`, `-ChallengeType`, and `-DryRun` parameters so the IIS-side
flow can dispatch without reimplementing the order logic. When either
of `-Domain` / `-Sans` is supplied the corresponding prompt is skipped;
plugin selection, plugin-args resolution, summary, and confirmation
still run.

## Pester

`tests/Unit/IIS/UC-9.11.Tests.ps1` — cases:

* `bundle=Yes`: 5 hostnames across 3 sites collapse to one
  `Invoke-OrderCertificate` call whose Domain is the first hostname
  and Sans contains the other four.
* `bundle=No`: 5 hostnames produce 5 separate calls, each with Sans
  count = 0 and the Domain set sorted equals the input set.
* Esc on the site picker calls `Invoke-OrderCertificate` zero times.
* A binding fixture made entirely of single-label hostnames still
  reaches one `Invoke-OrderCertificate` call (warn-but-allow contract).
* `-DryRun` propagation: when the IIS flow is entered with `-DryRun`,
  every dispatched `Invoke-OrderCertificate` call carries `-DryRun`
  and the post-issuance WebHosting import + rebind are never invoked
  (UC-9.17).
