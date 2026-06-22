---
applyTo: "**/*.ps1,**/*.psm1"
---

# Posh-ACME 4.x usage (PoshTUI)

Domain rules for calling Posh-ACME correctly. Each rule states *why*, with a
preferred and an avoided form. These encode real defects from the previous
implementation — do not reintroduce them.

## 1. Batch renewal uses `-AllOrders`
`-RenewAll` is not a real parameter. Reason: the cmdlet's switch is `-AllOrders`
(force with `-Force`); `Submit-Renewal` returns `PACertificate` objects only for
orders it actually renewed.
```powershell
# Preferred
Submit-Renewal -AllOrders            # add -Force to ignore RenewAfter
# Avoid
Submit-Renewal -RenewAll
```

## 2. Validation plugins go through `-Plugin`
Reason: `-DnsPlugin` was removed from `New-PACertificate` in 4.x. `WebSelfHost` is
an HTTP-01 plugin, still passed via `-Plugin`.
```powershell
# Preferred
New-PACertificate $names -Plugin WebSelfHost
New-PACertificate $names -Plugin Route53 -PluginArgs @{ R53ProfileName = 'poshacme' }
# Avoid
New-PACertificate $names -DnsPlugin WebSelfHost
```

## 3. Cert store: `-Install` means `LocalMachine\My`
Reason: `New-PACertificate -Install` imports to the Personal store, **not**
WebHosting. To control the store, skip `-Install` and use `Install-PACertificate`.
Issuance store, the binding `StoreName`, and any UI label must all be one value.
```powershell
# Preferred — explicit, configurable store
New-PACertificate $names -Plugin WebSelfHost           # no -Install
Get-PACertificate $names[0] |
    Install-PACertificate -StoreLocation LocalMachine -StoreName WebHosting
# then bind with StoreName 'WebHosting'

# Avoid — claims/uses WebHosting while -Install actually wrote to My
New-PACertificate $names -Plugin WebSelfHost -Install   # cert is in My, bind says WebHosting -> broken
```

## 4. Shared profile across SYSTEM needs portable encryption
Reason: secure plugin args (DNS plugins) are DPAPI-encrypted to the current
user+machine; they will not decrypt when the SYSTEM scheduled task reads the
shared `POSHACME_HOME`. Switch such accounts to portable AES once.
```powershell
# For any account that stores secure plugin args (DNS-01):
Set-PAAccount -UseAltPluginEncryption
# WebSelfHost has no secure args, so this is a no-op for the default HTTP path,
# but still required for DNS accounts used by the unattended runner.
```
Surface a warning in account management when an account has secure plugin args but
alt encryption is off.

## 5. Date fields may be string or DateTime
Reason: `RenewAfter`/`NotAfter` are `DateTime` in some versions and ISO-8601
strings in others; `.ToString('fmt')` throws on the string case. Normalize first.
```powershell
function ConvertTo-DateTime {
    param($Value)
    if (-not $Value) { return $null }
    if ($Value -is [datetime]) { return $Value }
    try { return [datetime]$Value } catch { return $null }
}
# Display ISO-8601, e.g. (ConvertTo-DateTime $o.RenewAfter)?.ToString('yyyy-MM-dd HH:mm')
```

## 6. Invalid orders block re-issue/renew
Reason: a prior failed challenge leaves an order in `Invalid`; Posh-ACME reuses
orders by MainDomain and the CA rejects the request
("expected status 'Pending' but had 'Invalid'"). Detect overlap and `Remove-PAOrder`
before issuing; refuse to renew an `Invalid` order (delete + re-issue instead).

## 7. `Set-PAServer` argument shape
Reason: it accepts a built-in alias (`LE_PROD`, `LE_STAGE`, ...) or a full
`https://` directory URL only. Custom short names (`acme.fragt.root.local`) are
rejected — pass the server's `.location` URL instead. Keep
`Resolve-PAServerArg`/`ConvertTo-PAServerArg`.

## 8. WebSelfHost operational notes
- No plugin args needed for port 80 / 120 s timeout; expose `WSHPort`/`WSHTimeout`
  only when overriding.
- Validation is always answered on port 80. http.sys path routing usually lets the
  listener coexist with running IIS sites.
- **Redirect landmine:** an HTTP→HTTPS redirect (URL Rewrite / `httpRedirect`)
  301s the `/.well-known/acme-challenge/` request and breaks validation. Exclude
  that path from redirects, or use a DNS plugin for forced-HTTPS sites.

## 9. Elevation
Both `New-PACertificate -Install`/`Install-PACertificate` and IIS binding edits
require an elevated session. The interactive TUI requires admin; the scheduled
runner uses SYSTEM.
