# UC-9.13 — IIS order flow asks DNS-01 vs HTTP-01 before dispatching

## Trigger

Operator picks **"2. Order new cert from site bindings"** from the IIS
Integration menu, or the top-level "Order new certificate" entry from
the main menu when `Invoke-OrderCertificate` is called without an
explicit `-ChallengeType`.

## Behaviour

Both flows now ask **once** for the ACME challenge type:

```
Challenge type [1=DNS-01, 2=HTTP-01]:
```

`1` / `dns-01` → DNS-01 family. `2` / `http-01` → HTTP-01 family.
Empty / invalid → re-prompt. Esc → cancel.

The `Invoke-IISOrderFromBindings` flow asks once at the top of the
flow and passes the chosen type into every `Invoke-OrderCertificate`
dispatch (both the bundle-into-one path and the one-cert-per-hostname
path). `Invoke-OrderCertificate` itself accepts `-ChallengeType` so
the per-order prompt is bypassed when the caller already knows.

The plugin picker then filters `Get-PAPlugin` by `ChallengeType`,
preserving fixtures without a `ChallengeType` property (the older
Posh-ACME shape and most test mocks) by treating missing/empty as
matching any family.

## Why

Without this, the order flow assumed DNS-01 and labelled its prompt
"DNS plugin name", silently making HTTP-01 plugins (WebRoot,
WebSelfHost, IIS, etc.) unreachable from the TUI. Operators who own
the IIS server and want to use HTTP-01 because their DNS is
external / firewalled now have a first-class choice.

The prompt is plain numeric input (Read-LineOrEscape rather than
Show-Menu) so the existing Pester test pattern that feeds Read-Host
answers continues to work for `Invoke-OrderCertificate`. Existing
UC-3.x tests pass `-ChallengeType 'dns-01'` explicitly to skip the
prompt entirely.

## Pester

`tests/Unit/IIS/UC-9.11.Tests.ps1` — case "UC-9.13: challenge type
prompt routes correctly through to Invoke-OrderCertificate" exercises
both '1' → 'dns-01' and '2' → 'http-01' routing by capturing the
`-ChallengeType` argument on dispatched `Invoke-OrderCertificate`
calls. The bundle=Yes / bundle=No cases assert the same thread-through
contract.

Existing UC-3.0x tests were updated to pass `-ChallengeType 'dns-01'`
so they skip the new prompt and exercise the rest of the flow
unchanged.
