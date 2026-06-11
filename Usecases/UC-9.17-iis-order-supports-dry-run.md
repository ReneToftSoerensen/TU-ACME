# UC-9.17 — IIS order flow supports -DryRun (staging, no store import, no rebind)

## Trigger

Operator picks **"2. Order new cert from site bindings"** from the IIS
Integration menu and explicitly chooses the dry-run variant (either via
a `[D] Dry-run` toggle in the order summary or by invoking the entry
point with `-DryRun`).

## Behaviour

The IIS thin layer (UC-9.11) treats dry-run exactly the same way the
top-level order flow does (UC-3.01, UC-4.01): the IIS-specific code
adds no extra account / server logic; it simply forwards `-DryRun` into
`Invoke-OrderCertificate` and **skips its own post-issuance side
effects**.

Concretely, when `-DryRun` is in effect:

1. **Discovery, grouping, CN+SAN derivation, FQDN validation, bundle
   prompt, and challenge-type prompt run unchanged** — the operator
   still drives the order from the binding inventory.
2. **Dispatch** — every `Invoke-OrderCertificate` call gets `-DryRun`
   appended. `Invoke-OrderCertificate` enters its dry-run try/finally:
   * `Use-TUACMEStagingAccount` swaps the active Posh-ACME account /
     server to staging.
   * `New-PACertificate` runs against the staging directory.
   * The `finally` block calls `Use-TUACMEProdAccount` and restores
     production, regardless of success / failure.
   * Event 1006 (`Dry-run certificate issued (staging)`) is written
     instead of Event 1003.
3. **WebHosting import (UC-9.14) is skipped.** The staging cert is
   never imported into `Cert:\LocalMachine\WebHosting`.
4. **Auto-rebind (UC-9.15) is skipped.** `Set-WebBinding` is never
   called. IIS binding state is byte-for-byte unchanged.
5. **Old-cert delete (UC-9.16) is not reachable** — it lives in the
   renewal helper and renewal never runs under `-DryRun` from the IIS
   menu.
6. **Plugin selection and plugin args still run.** Dry-run exercises
   the full plugin contract on purpose; that is the entire point of a
   staging order.

The result of a successful IIS dry-run is: a staging cert visible in
the staging Posh-ACME store, an Event 1006 in the log, production
restored, and zero changes to `Cert:\LocalMachine\WebHosting` or any
IIS binding.

## Why

Without this UC, the IIS order flow would either be production-only
(operators can't smoke-test plugin args, DNS provider auth, or
WebRoot path validity without risking a real binding flip) or would
need a parallel staging code path that re-implements dry-run inside
the IIS layer. Both are wrong: the locked decision (root CLAUDE.md
§4) is that dry-run is the **single dedicated path** that swaps to
staging and restores prod. The IIS layer must inherit that path, not
mirror it.

Skipping the WebHosting import and the auto-rebind under `-DryRun` is
not a side effect — it is the contract. A dry-run that mutates IIS
state would be indistinguishable from a real order on every dimension
that matters operationally.

## Pester

`tests/Unit/IIS/UC-9.17.Tests.ps1`:

* **dry-run propagation** — invoking `Invoke-IISOrderFromBindings
  -DryRun` against a bundle=Yes fixture results in exactly one
  `Invoke-OrderCertificate` call whose bound parameters include
  `DryRun = $true`.
* **no WebHosting import under dry-run** — `Import-PfxCertificate` is
  called zero times during a `-DryRun` order.
* **no auto-rebind under dry-run** — `Set-WebBinding` is called zero
  times during a `-DryRun` order.
* **prod path still imports + rebinds** — the same fixture without
  `-DryRun` results in one `Import-PfxCertificate` call into
  `Cert:\LocalMachine\WebHosting` and one `Set-WebBinding` call per
  originating binding (regression guard against accidentally tying the
  prod path to the dry-run skip).

**Implementation:** `TU-ACME/Private/IIS/Invoke-IISOrderFromBindings.ps1`
(forwards `-DryRun`; gates UC-9.14 and UC-9.15 on `-not $DryRun`)
