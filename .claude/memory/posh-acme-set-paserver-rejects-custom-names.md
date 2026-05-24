# Posh-ACME 4.32 `Set-PAServer -DirectoryUrl` rejects custom server short names

**Symptom**: `Cannot validate argument on parameter 'DirectoryUrl'. acme is invalid. Must be ZEROSSL_PROD,GOOGLE_STAGE,LE_STAGE,GOOGLE_PROD,SSLCOM_RSA,LE_PROD,SSLCOM_ECC,ACTALIS_PROD or a full https:// URL.`
**Discovered**: 2026-05-22 via dashboard's posh-acme.log on a user environment with three internal CAs (`acme`, `acme.fragt.root.local`, `acme01p`)
**Affects**: Posh-ACME 4.32+ (earlier minors had looser validation)

## What broke
Cross-server cert enumeration in the dashboard worked for built-in servers (`LE_PROD`, `le_stage`) but skipped every custom-named CA. The user's `df-bpxt4s2-ws` cert lived on `acme`, so it never appeared in the table even though `Get-PAServer -List` returned it.

## Root cause
Posh-ACME 4.32 tightened `Set-PAServer`'s `-DirectoryUrl` parameter validation to a `[ValidateSet]` of built-in short names **plus** a "starts with `https://`" pattern. Custom server short names (the `Name` property on a saved-server object) are not in the validation list, so positional `Set-PAServer acme` is rejected even though `Get-PAServer -List` happily returns the saved server.

## Fix
Always pass `$srv.location` (the full URL), never `$srv.Name`. Every saved server has both. The URL is accepted for built-in servers too (their location is the LE production/staging URL).

```powershell
# WRONG — fails for custom CAs
Set-PAServer $srv.Name -ErrorAction Stop

# RIGHT — works for both built-in and custom
Set-PAServer -DirectoryUrl $srv.location -ErrorAction Stop
```

Applied in `Get-TUACMEAllCertificates.ps1` (server iteration + entry/exit restore), `Invoke-CertificateDashboard.ps1` (try/finally restore), and `_Switch-PAContext` (use `$Cert.ServerLocation` not `$Cert.ServerName`).

## See also
- `posh-acme-folder-layout.md`
