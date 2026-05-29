# UC-8.10 — Renewal handles no-certs case as a benign no-op

## Trigger

`Invoke-RenewalBackground.ps1` runs (either as the scheduled task or
foreground from the Automation menu) on a host where Posh-ACME has zero
certificates in its store — typically a fresh install before the first
`Order new certificate` flow has been completed, or after every cert has
been revoked.

## Behaviour

The script snapshots `Get-PACertificate -List` into `$before`. If the
snapshot is empty it writes **Event 1001** with message
`"Renewal pass completed; no certs to renew."` and returns. **Submit-Renewal
is never called**, no failure mail is sent, and no Event 3001 is written.

The actual `Submit-Renewal` call is additionally wrapped in a localised
`try/catch` that swallows any `"No order found"` exception still bubbling
through (defence-in-depth against races where a cert is deleted between
the snapshot and the call). Any other Submit-Renewal failure still
bubbles to the outer catch as a real Event 3001.

## Why

`Submit-Renewal` in Posh-ACME implements the empty-order-list case as
`throw "No order found for the specified parameters."`. That's a
terminating error originating inside the Posh-ACME module — neither
`-ErrorAction Continue` on the call site nor `$ErrorActionPreference =
'SilentlyContinue'` at the script level can suppress it, because the
caller's preference doesn't propagate across module boundaries for
explicit `throw`s.

Before this UC, the outer `catch` in the renewal script treated that
throw exactly like a real renewal failure: wrote Event 3001, looked up
SMTP settings, and sent a "renewal FAILED" mail. The first ever
foreground renewal on a freshly-deployed host would surface as an alarm.

## Pester

`tests/Scripts/Invoke-RenewalBackground.Tests.ps1` — case "UC-8.10:
no-certs case is benign — Event 1001, never 3001, no Submit-Renewal":
mocks `Get-PACertificate` to return `@()`, runs the script foreground,
and asserts (a) Submit-Renewal was never called, (b) Send-TUACMEMail
was never called, (c) exactly one Event 1001 with the "no certs to
renew" message was written, (d) zero Event 3001s.
