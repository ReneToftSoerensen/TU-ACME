# Posh-ACME v4 has no `Remove-PACertificate`

**Symptom**: `The term 'Remove-PACertificate' is not recognized as a name of a cmdlet …`
**Discovered**: 2026-05-21, on Windows + PowerShell 7.5.4 + Posh-ACME 4.32.0
**Affects**: Posh-ACME 4.x (all minor versions verified through 4.32)

## What broke
TU-ACME's dashboard had a `[D] Delete` action that called `Remove-PACertificate -MainDomain $X -Force`. The cmdlet does not exist — there is only `Remove-PAAccount`. Pester tests passed because Bootstrap.ps1 had a global stub, but every real invocation failed.

## Root cause
Posh-ACME v4's `FunctionsToExport` list does not contain `Remove-PACertificate`. Local cert removal is intentionally not exposed as a cmdlet — `Get-PACertificate -List` discovers certs lazily by scanning the filesystem.

## Fix
Delete the cert directory directly. Each cert lives in its own folder:

```
$env:LOCALAPPDATA\Posh-ACME\<ServerID>\<AccountID>\<CertName>\
```

Wiping the folder is equivalent to removing the cert from the local store. The cert at the ACME server is unaffected — this is a forget, not a revoke. Implemented as `_Remove-TUACMECertDir` in `TU-ACME/Private/Certificates/Invoke-CertificateDashboard.ps1`. Sanity-check before `Remove-Item -Recurse -Force` that the folder contains `cert.cer` or `order.json`.

## See also
- `posh-acme-folder-layout.md`
- `posh-acme-revoke-vs-delete.md`
