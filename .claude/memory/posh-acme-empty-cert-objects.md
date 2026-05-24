# Posh-ACME `Get-PACertificate -List` can return phantom cert objects

**Symptom**: Dashboard renders a row with every column `(unknown)` / `Unknown` / `-1` / `EXPIRED`. Trying to delete it errors with `Certificate has no CertFile path; cannot determine folder to remove.`
**Discovered**: 2026-05-22 on a user environment with abandoned pending orders
**Affects**: Posh-ACME 4.x (verified on 4.32)

## What broke
`Get-PACertificate -List` is supposed to enumerate issued certs, but it sometimes surfaces partial entries — typically a pending order whose validation failed, or a half-deleted folder, or an in-progress `New-PACertificate` whose parent process was abandoned. The returned object has `MainDomain`, `CertFile`, `Thumbprint`, and `NotAfter` all empty / `$null`. Without a guard the row reaches the UI and confuses the user.

## Root cause
Posh-ACME constructs cert objects by reading order.json from each folder under `<AccountID>\<CertName>\`. If a folder exists but the cert was never issued, the object is constructed with empty X.509-derived fields.

## Fix
Filter in `Get-TUACMEAllCertificates`: a cert is actionable only if it has either a populated `MainDomain` OR a `CertFile` pointing to a file that exists on disk. Without one of those there is no name to show, no folder to delete, no order to renew.

```powershell
$hasName = [bool] $c.MainDomain
$hasFile = $c.CertFile -and (Test-Path -LiteralPath $c.CertFile)
if (-not $hasName -and -not $hasFile) {
    $skipped++
    continue
}
```

Earlier (0.8.1) version required all four of MainDomain/CertFile/Thumbprint/NotAfter to be empty before skipping — too lenient. The two-field check is the right call.

## See also
- `posh-acme-internal-ca-empty-fields.md`
- `posh-acme-folder-layout.md`
