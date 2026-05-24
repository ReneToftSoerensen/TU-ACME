# Posh-ACME v4 has no native `-PostScript` / post-renewal hook

**Symptom**: Earlier docs referenced `Set-PAConfig -PostScript ...` for wiring an IIS-rebind callback after renewal. The cmdlet doesn't exist (see `posh-acme-no-set-paconfig.md`) and v4 has no equivalent.
**Discovered**: 0.5.x development
**Affects**: Posh-ACME 4.x (all versions). Earlier v3 had a post-renewal hook.

## What broke
Initial UC-8.3 design assumed `Posh-ACME` would call a registered script after each `Submit-Renewal` succeeded. There is no such mechanism in v4.

## Fix
`Invoke-RenewalBackground.ps1` (TU-ACME's Scheduled-Task script) implements the rebind itself:

1. Snapshot `Get-PACertificate -List | Select MainDomain, Thumbprint` **before** `Submit-Renewal`.
2. Run `Submit-Renewal`.
3. Snapshot again **after**.
4. For every cert whose `Thumbprint` changed, call `Update-IISBindingForCert -OldThumbprint $old -NewThumbprint $new` (dot-sourced from `Posh-ACME-IIS-Plugin.ps1`).

No registration required, no shared global state — the renewal wrapper IS the post-renewal hook.

## See also
- `posh-acme-no-set-paconfig.md`
- `TU-ACME/Scripts/Invoke-RenewalBackground.ps1`
- `TU-ACME/Scripts/Posh-ACME-IIS-Plugin.ps1`
