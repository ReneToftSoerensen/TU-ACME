---
applyTo: "**/*.ps1,**/*.psm1"
---

# IIS bindings via IISAdministration (PoshTUI)

Patterns for reading and editing IIS bindings with `Microsoft.Web.Administration`
through the `IISAdministration` module. Reason for these rules: binding edits are
easy to get subtly wrong (thumbprint byte handling, SNI flag, commit timing) and a
wrong edit silently breaks TLS.

## Enumerating
- Use `Get-IISServerManager` and iterate `.Sites` / `.Bindings`.
- `BindingInformation` is the string `IP:Port:HostHeader` — split on `:` with a
  limit of 3. Empty IP means `*`.
```powershell
$parts   = $b.BindingInformation -split ':', 3
$ip      = if ($parts[0]) { $parts[0] } else { '*' }
$port    = if ($parts[1]) { $parts[1] } else { '80' }
$hostHdr = if ($parts.Count -ge 3) { $parts[2] } else { '' }
```
- A binding's current cert is `byte[] $b.CertificateHash` + `$b.CertificateStore`.
  Render the hash as a lowercase hex string for comparison/display.

## Thumbprint <-> byte[] (one helper, reused)
Reason: bindings store the thumbprint as bytes; the cert store and Posh-ACME use
the hex string. Centralize the conversion; never inline it twice.
```powershell
function ConvertTo-ThumbprintBytes {
    param([Parameter(Mandatory)][string]$Thumbprint)
    $bytes = [byte[]]::new($Thumbprint.Length / 2)
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $bytes[$i] = [Convert]::ToByte($Thumbprint.Substring($i * 2, 2), 16)
    }
    return ,$bytes
}
```

## Editing (rebind / create)
- Re-point an existing HTTPS binding by setting `CertificateHash` (bytes) and
  `CertificateStore`, then `$mgr.CommitChanges()` **once** after the edits.
- Create a new HTTPS binding via `$site.Bindings.CreateElement('binding')`, set
  `Protocol='https'`, `BindingInformation`, `CertificateStore`, `CertificateHash`,
  and SslFlags, then `$site.Bindings.Add($new)` and commit.
- **SNI:** set `SslFlags = 1` when a host header is present (`0` when not). The
  setter may not exist on very old IIS — guard with try/catch.
```powershell
$new = $site.Bindings.CreateElement('binding')
$new.Protocol           = 'https'
$new.BindingInformation = "$ip`:$port`:$hostHdr"
$new.CertificateStore   = $StoreName
$new.CertificateHash    = ConvertTo-ThumbprintBytes $Thumbprint
try { $new.SslFlags = 1 } catch { }   # SNI when host header present
$site.Bindings.Add($new)
$mgr.CommitChanges()
```
- Idempotency: before creating, check for an existing https binding with the same
  `BindingInformation`; before rebinding, skip if it already carries the target
  thumbprint.

## Store alignment
The binding's `CertificateStore` must equal the store the certificate was actually
imported into (see Posh-ACME rule #3). Drive both from the single `CertStore`
config value (default `WebHosting`).

## PowerShell 7 caveat
`IISAdministration` is the supported module on PS7; if `Get-IISServerManager`
throws an assembly-load error on a given host, surface a clear message (the
`Microsoft.Web.Administration` types failed to load) rather than a bare exception,
and treat it as a fatal setup error.

## ShouldProcess
`Set-IISBindingCertificate` and `New-IISHttpsBinding` are state-changing:
`[CmdletBinding(SupportsShouldProcess)]` and gate the commit so `-WhatIf`/Dry-Run
make no changes.
