# `Set-PAConfig` does not exist in Posh-ACME v4

**Symptom**: `The term 'Set-PAConfig' is not recognized …` if calling it directly. Older Posh-ACME docs / tutorials mention it.
**Discovered**: 0.5.x development; confirmed via `(Get-Module Posh-ACME).ExportedCommands.Keys`
**Affects**: Posh-ACME 4.x (all versions). The cmdlet existed in v3.

## What broke
Plans to register a global PostScript via `Set-PAConfig -PostScript ...` won't work — `Set-PAConfig` was removed in v4.

## Root cause
Posh-ACME v4 redesigned its configuration model. Server-level settings now live in `Set-PAServer`; account-level in `Set-PAAccount`; order-level in `Set-PAOrder`. There is no longer a single global config cmdlet.

## Fix
- Server config → `Set-PAServer`
- Account config → `Set-PAAccount`
- Order config → `Set-PAOrder` (including `-NewKey` for next-renewal key rotation — see `posh-acme-set-paorder-newkey.md`)
- No global hook for post-renewal — implement it in the renewal wrapper (see `posh-acme-no-postscript-hook.md`)

Verify what exists with:
```powershell
(Get-Module -Name Posh-ACME).ExportedCommands.Keys | Sort
```

## See also
- `posh-acme-no-postscript-hook.md`
- `posh-acme-set-paorder-newkey.md`
