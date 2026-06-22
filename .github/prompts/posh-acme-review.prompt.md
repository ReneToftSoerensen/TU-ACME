---
mode: agent
description: Review PowerShell for the known Posh-ACME 4.x and IIS binding defects before merge.
tools: ['codebase', 'search']
---

# Posh-ACME / IIS review

Review ${input:target:file or folder, default ./src} for correctness against the
project rules. Report findings as a table: Severity | File:Line | Issue | Fix.
Do not edit files — review only.

## Must-flag (blocking)
- `Submit-Renewal -RenewAll` → must be `-AllOrders` (`-Force` to override RenewAfter).
- `-DnsPlugin` on `New-PACertificate`/order cmdlets → must be `-Plugin`.
- `New-PACertificate -Install` paired with a non-`My` binding `StoreName`, or a UI
  label claiming WebHosting → store mismatch; use `Install-PACertificate
  -StoreName <store>` and align issuance/binding/label to one `CertStore` value.
- DNS-plugin account used by the SYSTEM renewal task without
  `Set-PAAccount -UseAltPluginEncryption` → will fail to decrypt under SYSTEM.
- `.ToString('fmt')` (or arithmetic) directly on `RenewAfter`/`NotAfter` without
  `ConvertTo-DateTime` → throws on string-typed values.
- `Set-PAServer` called with a custom short name instead of an alias or
  `https://` directory URL.
- Thumbprint↔byte conversion inlined more than once, or a binding edit that does
  not `CommitChanges()`.
- Duplicated rebind/install logic between the wizard and `PoshAcme-Renew.ps1`.

## Should-flag (non-blocking)
- Cmdlet aliases (`?`, `%`, `gci`, ...), untyped params, missing
  `[CmdletBinding(SupportsShouldProcess)]` on a state-changing function.
- Missing `try/catch` isolation in loops over certs/orders/bindings.
- Non-idempotent binding create/rebind (no "already present / already on target
  thumbprint" guard).
- HTTP→HTTPS redirect on a WebSelfHost site without excluding
  `/.well-known/acme-challenge/`.
- Dates rendered in a non-ISO-8601 format.

## Output
End with a one-line verdict: `BLOCK` (any must-flag present) or `OK` plus the
count of should-flags.
