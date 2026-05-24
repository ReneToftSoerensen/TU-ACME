# Posh-ACME `[ValidateScript({ Test-ValidX $_ })]` attributes reference private functions

**Symptom**: `The term 'Test-ValidDirUrl' is not recognized as a name of a cmdlet …` (and `Test-ValidFriendlyName`, `Test-ValidKeyLength`, `Test-ValidPlugin`, `Test-WinOnly`) when invoking a proxied Posh-ACME cmdlet.
**Discovered**: 0.5.4 / 0.5.5 development cycle
**Affects**: Any Posh-ACME cmdlet with a `ValidateScript` referencing a private validator. Confirmed on `Set-PAServer`, `Set-PAAccount`, `New-PACertificate`.

## What broke
`Initialize-PALogging.ps1` generates proxies via `[ProxyCommand]::Create($original)`. The generator copies `[ValidateScript({...})]` attributes verbatim. The script blocks reference functions like `Test-ValidDirUrl` that are private to Posh-ACME, so parameter binding fails when the proxy is invoked from TU-ACME's scope.

## Root cause
Same scope-leak as `posh-acme-private-types-in-proxy.md`. ProxyCommand assumes the proxy will run in the same session state as the original — not true when one module proxies another.

## Fix
Strip every `[ValidateScript(...)]` attribute from the proxy body. The wrapped cmdlet still has its own copy and re-validates inside Posh-ACME's scope when we delegate via `Posh-ACME\<cmd>`. Lazy regex handles both one-line and multi-line attribute bodies:

```powershell
$body = $body -replace '(?s)\s*\[ValidateScript\(.*?\)\]\s*\r?\n', ''
```

`(?s)` enables `.` to match newlines; `.*?` is lazy so we don't accidentally swallow a later `)]`.

## See also
- `posh-acme-private-types-in-proxy.md`
- `posh-acme-proxy-getcommand-recursion.md`
