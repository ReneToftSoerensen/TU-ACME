# `current-order.txt` orphan survives cert-folder deletion → dashboard ghost

**Symptom**: After `[D] Delete` on a cert in the TU-ACME dashboard, returning to the table view shows a ghost row with empty fields ("(unknown)" everywhere). `Get-PACertificate -List` from an interactive prompt against the same active server returns nothing.
**Discovered**: 2026-05-22 against an internal ACME CA (`https://acme`), Posh-ACME 4.32.
**Affects**: Posh-ACME 4.x (all minors verified).

## What broke
`_Remove-TUACMECertDir` did its job — `Remove-Item -Recurse -Force` on the cert folder. But the account folder one level up (`<server>\<account>\`) still contains `current-order.txt` pointing at the now-deleted cert name. The cross-server enumeration in `Get-TUACMEAllCertificates` (or some Posh-ACME code path it triggers) sees the dangling pointer and constructs a partial cert object — `MainDomain` populated from the pointer text, `CertFile` either null or pointing at a path that no longer exists.

The dashboard's keep-rule was `hasName OR hasFile`; the partial entry has `hasName` true, so it passed through and rendered as a row with everything else empty.

## Repro
1. Issue a cert: `New-PACertificate -Domain df-bpxt4s2-ws -Plugin ...`
2. Confirm `current-order.txt` exists: `Get-Content "$env:LOCALAPPDATA\Posh-ACME\<server>\<account>\current-order.txt"` → `df-bpxt4s2-ws`
3. Delete the cert folder: `Remove-Item "$env:LOCALAPPDATA\Posh-ACME\<server>\<account>\df-bpxt4s2-ws" -Recurse -Force`
4. `current-order.txt` is untouched — still says `df-bpxt4s2-ws`.
5. Open the TU-ACME dashboard → ghost row.

## Fix
`_Remove-TUACMECertDir` (in `TU-ACME/Private/Certificates/Invoke-CertificateDashboard.ps1`) computes the cert's leaf name and its parent (the account directory), then after the recursive delete:

```powershell
$pointer = Join-Path $accountDir 'current-order.txt'
if (Test-Path -LiteralPath $pointer) {
    $target = (Get-Content -Path $pointer -Raw).Trim()
    if ($target -eq $certLeaf) {
        Remove-Item -Path $pointer -Force
    }
}
```

Conditional on the pointer matching: don't nuke a `current-order.txt` that has already moved on to a different active order. The matching comparison is on the trimmed file content vs. the cert folder leaf — Posh-ACME writes one without an EOL.

## Why not a stronger dashboard filter
A tighter "require cert.cer on disk" filter in `Get-TUACMEAllCertificates` would suppress the symptom but leave the orphan pointer on disk forever, leaking surface area for other future Posh-ACME calls (`Set-PAOrder`, etc.) to misbehave. Better to clean up at the source.

## See also
- `posh-acme-empty-cert-objects.md` (the earlier broader phantom filter)
- `posh-acme-no-remove-pacertificate.md` (why we delete folders by hand)
- `posh-acme-revoke-vs-delete.md`
