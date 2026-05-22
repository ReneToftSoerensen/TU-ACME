# Posh-ACME default store is per-user, breaks SYSTEM scheduled renewals

**Symptom**: Scheduled Task running as SYSTEM completes with "no certificates required renewal" even when the admin has issued certs interactively. Manual `Get-PACertificate -List` as the admin returns the certs; as SYSTEM (via `psexec -s -i powershell`) returns nothing.
**Discovered**: 2026-05-22 by user inspecting `C:\Users\402029\AppData\Local\Posh-ACME\…\cert.cer` and realizing SYSTEM's `%LOCALAPPDATA%` resolves to a different folder entirely.
**Affects**: Posh-ACME 4.x (all minors).

## What broke
Posh-ACME's data root defaults to `$env:LOCALAPPDATA\Posh-ACME`. `%LOCALAPPDATA%` resolves per-user:

- Admin (RDP'd in): `C:\Users\<admin>\AppData\Local\Posh-ACME`
- SYSTEM: `C:\Windows\System32\config\systemprofile\AppData\Local\Posh-ACME`

The scheduled task ran from SYSTEM's profile, which is empty. No certs, no accounts, no renewal candidates. Submit-Renewal silently no-ops.

## Root cause
TU-ACME never set `POSHACME_HOME`. Posh-ACME reads that env var on Import-Module to override the default root, but nothing in the project did so — neither the interactive entrypoint nor the renewal background script. Each principal therefore got its own private store.

## Fix
New helper `Initialize-TUACMEStore` in `TU-ACME/Private/Helpers/Initialize-TUACMEStore.ps1`:

1. Computes `$env:ProgramData\TU-ACME\Posh-ACME` (sibling to `config.json`).
2. Creates the folder if missing.
3. When elevated: explicit ACL `Administrators (Full) + SYSTEM (Full)` with `ContainerInherit, ObjectInherit`. Default ProgramData inheritance already covers it, but explicit rules survive non-default parent ACLs.
4. Sets `$env:POSHACME_HOME = $storeRoot` for the current process.
5. When elevated, also persists `POSHACME_HOME` machine-wide via `[Environment]::SetEnvironmentVariable(..., 'Machine')` so new shells and the SYSTEM task inherit without re-running TU-ACME.

Wired in two places, both **before** `Import-Module Posh-ACME`:
- `TU-ACME.psm1` at module load (dot-sourced explicitly before the eager Posh-ACME import).
- `Scripts/Invoke-RenewalBackground.ps1` (the scheduled-task entrypoint).

Order matters: Posh-ACME caches the resolved store path on first cmdlet call, so setting `POSHACME_HOME` after a Posh-ACME function runs is a no-op for that session.

## Caveat — plugin args still DPAPI-bound
The cert files, account keys, and order metadata are plain JSON/PEM and cross the user boundary fine once the folder ACL allows both principals. **Plugin args** (DNS API tokens etc.) are DPAPI-encrypted to the calling user by default — SYSTEM still can't decrypt what the admin saved. Fix is `Set-PAAccount -ID <id> -UseAltPluginEncryption $true` per account: switches plugin-arg encryption to an AES key file inside the account folder, which both principals can read because the folder is ACL'd. TU-ACME does **not** force this automatically (per user preference: ACME account data is not critical enough to need encryption gymnastics). Internal-CA / HTTP-01 setups without credentialed plugins skip the issue entirely.

## Migration
`Invoke-TUACMEStoreMigration` runs at `Start-TUACME` startup. Triggers only when the legacy `$env:LOCALAPPDATA\Posh-ACME` has at least one `cert.cer` and the new store is empty. Copies (not moves) the tree into the new location and leaves the legacy folder as a rollback.

## See also
- `posh-acme-current-order-orphan.md`
- `posh-acme-no-remove-pacertificate.md`
