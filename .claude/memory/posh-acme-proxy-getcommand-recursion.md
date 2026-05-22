# `ProxyCommand.Create` generates unqualified `GetCommand` for function-typed wrapped commands

**Symptom**: Calling a proxied Posh-ACME cmdlet hangs / overflows the stack the first time it's invoked.
**Discovered**: Initial PA-logging proxy implementation
**Affects**: Every Posh-ACME cmdlet (they're all functions, not compiled cmdlets).

## What broke
`[ProxyCommand]::Create($original)` emits a body that looks like:

```powershell
$wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Get-PACertificate',
    [System.Management.Automation.CommandTypes]::Function)
```

After our proxy is installed as `function:script:Get-PACertificate`, that unqualified lookup resolves back to *our* proxy — infinite recursion.

## Root cause
ProxyCommand assumes the original command is uniquely resolvable by short name when the proxy runs. That assumption breaks the moment we install a same-named proxy in a scope that's searched before the wrapped module.

## Fix
Rewrite the `GetCommand` call to module-qualify the lookup so it always hits Posh-ACME's real function:

```powershell
$body = $body -replace "\.GetCommand\('$name'", ".GetCommand('Posh-ACME\$name'"
```

The wrapped `Posh-ACME\Get-PACertificate` is the real function regardless of any proxy installed in another module's scope.

## See also
- `posh-acme-validatescript-strip.md`
- `posh-acme-private-types-in-proxy.md`
- `ps51-eager-import-posh-acme.md`
