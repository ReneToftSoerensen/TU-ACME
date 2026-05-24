# `New-PAAccount` returns `$null` on Posh-ACME 4.32+

**Symptom**: After "Create new account" the user sees `Error: New-PAAccount returned nothing` even though the account was actually created at LE Staging.
**Discovered**: 2026-05-21 against Let's Encrypt Staging
**Affects**: Posh-ACME 4.32+ (earlier minors returned the account object)

## What broke
`Invoke-AccountMenu`'s create-account flow captured `$acc = New-PAAccount ...` and treated `$null` as failure. On 4.32 the cmdlet now returns no output even on success.

## Root cause
Behavior change in Posh-ACME 4.32 — the cmdlet still creates the account on disk but no longer writes the result object to the pipeline. The replacement is to call `Get-PAAccount` (currently selected) or `Get-PAAccount -List` and filter for the new account.

## Fix
Three-tier discovery in `_Register-NewAccount`:

1. Capture the New-PAAccount return value. If non-null, use it.
2. Otherwise call `Get-PAAccount` (current account on this server). If non-null, use it.
3. Otherwise `Get-PAAccount -List | Where status -eq 'valid' | Select -Last 1`.

Filter on `status='valid'` not on contact email — LE Staging echoes an empty `contact` field even when an address was provided.

After creating, explicitly call `Set-PAAccount -ID $acc.id` so the new account is active in this session (Posh-ACME leaves the previously-active account selected after `New-PAAccount`).

## See also
- `TU-ACME/Private/Accounts/Invoke-AccountMenu.ps1`
