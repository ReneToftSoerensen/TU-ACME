# `[RevocationReasons]` (and other Posh-ACME private types) break ProxyCommand proxies

**Symptom**: `Error: Unable to find type [RevocationReasons].` when calling our `Revoke-PACertificate` proxy — even though the caller never passes `-Reason`.
**Discovered**: 2026-05-22 testing `[V] Revoke` against an internal ACME CA
**Affects**: Any Posh-ACME cmdlet whose parameters are typed against an enum/class defined inside the Posh-ACME module.

## What broke
`Initialize-PALogging.ps1` installs proxies for Posh-ACME cmdlets via `[System.Management.Automation.ProxyCommand]::Create($original)`. ProxyCommand copies the entire parameter block verbatim, including the type annotation `[RevocationReasons]` on `-Reason`. PowerShell tries to resolve that type at parameter-binding time and fails because the enum is defined inside Posh-ACME's session state, not TU-ACME's.

## Root cause
Same class of bug as the `Test-ValidDirUrl` / `Test-ValidFriendlyName` `ValidateScript` strip already in place. ProxyCommand.Create doesn't care that the type isn't reachable from the consumer module's scope.

## Fix
Strip the bare `[TypeName]` line from the proxy body. The wrapped Posh-ACME cmdlet keeps its real param block and re-validates inside its own scope when we delegate via `Posh-ACME\<cmd>`. In `Initialize-PALogging.ps1`:

```powershell
$privateTypes = @('RevocationReasons')
foreach ($t in $privateTypes) {
    $body = $body -replace "(?m)^\s*\[$t\]\s*\r?\n", ''
}
```

When future Posh-ACME private types surface, append to `$privateTypes` — no other code change needed.

## See also
- `posh-acme-validatescript-strip.md`
- `posh-acme-proxy-getcommand-recursion.md`
