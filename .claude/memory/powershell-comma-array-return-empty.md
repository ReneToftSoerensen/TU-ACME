# `return ,$arr` over-wraps when the array is empty → caller sees Count=1

**Symptom**: Certificate Dashboard renders a `(unknown) (unknown) Unknown -1 EXPIRED` ghost row on a fresh install with no Posh-ACME data. `posh-acme.log` proves `Get-TUACMEAllCertificates` finished with `Kept=0 Skipped=0`, yet the dashboard table shows one row.
**Discovered**: 2026-05-22 on a clean Windows machine running TU-ACME 0.10.2.

## What broke
`Get-TUACMEAllCertificates` ended with:

```powershell
return ,$all.ToArray()
```

The leading unary comma is the standard PS idiom for "always return an array, even with a single element". For a non-empty `$all` it works fine — the comma wraps the array so `@(call)` preserves it.

But for **empty** `$all`, the trick breaks down:

- `$all.ToArray()` → `Object[0]` (empty array)
- `,$all.ToArray()` → `Object[1]` whose single element is the empty `Object[0]`

When PowerShell returns that from a function, the pipeline unrolls the **outer** wrapper and emits the inner `Object[0]` as one pipeline item. The dashboard's `@(Get-TUACMEAllCertificates)` then re-wraps that one item, ending up with `$certs.Count == 1` whose single element is the empty inner array.

The foreach over `$certs` runs once with `$_` empty. `$_.MainDomain` / `$_.CertFile` / `$_.NotAfter` are all null → `_Get-TUACMECertDisplayName` returns `(unknown)`, `Server` falls through to `(unknown)`, `Days = -1`, `Status = EXPIRED`. Hello ghost row.

## Fix
Drop the comma:

```powershell
return $all.ToArray()
```

- Empty `Object[0]` → pipeline emits nothing → caller's `@()` is empty → `Count == 0`.
- Single-element `Object[1]` → pipeline emits one item → caller's `@()` wraps → `Count == 1`.
- N-element → likewise.

The dashboard already wraps with `@(Get-TUACMEAllCertificates)`, so the array semantics it needs are guaranteed without the comma trick.

## Rule of thumb
The `return ,$arr` idiom is only safe when `$arr` is **definitely non-empty**. If the caller already wraps with `@()`, drop the comma entirely. If the function might return zero elements and the caller does not wrap, the correct alternatives are:

- `Write-Output -NoEnumerate $arr` (explicit no-unroll)
- `if ($arr.Count -eq 0) { return @() } else { return ,$arr }` (branch on empty)

## See also
- `posh-acme-current-order-orphan.md` (the earlier ghost-row hypothesis we chased before finding this one)
- `posh-acme-empty-cert-objects.md` (the original filter against partial cert entries)
