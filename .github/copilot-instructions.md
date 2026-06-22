# PoshTUI — Copilot repository instructions

PoshTUI is a Windows-only, interactive terminal UI over **Posh-ACME 4.x** for
issuing and renewing certificates against an internal ACME CA, with IIS binding
integration. Built as a PowerShell 7 module. There is also a headless renewal
runner driven by a Windows Scheduled Task running as SYSTEM.

The work is specified in `ISSUE-01-rewrite.md` (module + interactive TUI) and
`ISSUE-02-renewal-runner.md` (`PoshAcme-Renew.ps1`). Read both before coding.

## Stack & layout

- PowerShell **7.0+**, elevated (admin required). Windows Server 2019+/Win10+ with IIS.
- Modules: `Posh-ACME` (>=4.x), `IISAdministration`, installed `-Scope AllUsers`.
- Module under `/src` (`PoshTui.psd1`/`.psm1`, `Public/`, `Private/`); entry point
  `Start-PoshTui`. Headless runner `PoshAcme-Renew.ps1` at repo root reuses
  `Private/Deploy.ps1` helpers. Tests in `/tests` (Pester 5).

## Build / test / run

- Import: `Import-Module ./src/PoshTui.psd1 -Force`
- Run: `Start-PoshTui`
- Lint: `Invoke-ScriptAnalyzer -Path ./src -Recurse` (must be clean)
- Test: `Invoke-Pester ./tests`

## Golden rules (full detail in `.github/instructions/`)

These are the defects from the prior implementation — never reintroduce them:

- Batch renewal is `Submit-Renewal -AllOrders` (force: `-Force`). **`-RenewAll`
  does not exist.**
- Pass validation plugins with `-Plugin` (e.g. `-Plugin WebSelfHost`). **`-DnsPlugin`
  was removed in Posh-ACME 4.x.**
- `New-PACertificate -Install` imports to `LocalMachine\My`, **not** WebHosting.
  For a specific store use `Install-PACertificate -StoreLocation LocalMachine
  -StoreName <store>`. Issuance store, binding `StoreName`, and the UI label must
  all come from one `CertStore` config key.
- Secure plugin args are DPAPI-encrypted per user+machine and will not decrypt
  under the SYSTEM scheduled task. Switch such accounts to portable AES with
  `Set-PAAccount -UseAltPluginEncryption`.
- `RenewAfter`/`NotAfter` may be `DateTime` or ISO-8601 string. Always normalize
  via the date helpers; never call `.ToString('fmt')` on the raw value. Display
  ISO-8601.
- `Set-PAServer` accepts a built-in alias or full `https://` URL only; for
  custom-named servers pass `.location` (the directory URL).

## Conventions

- Follow the user's PowerShell style in `.github/instructions/powershell.instructions.md`:
  approved verbs, PascalCase functions, **full cmdlet names (no aliases)**,
  explicit param types, `[CmdletBinding(SupportsShouldProcess)]` on
  state-changing functions, `Set-StrictMode -Version Latest`.
- This is a TUI: `Write-Host` is the correct output channel for the interface;
  data-returning helpers still emit objects, not host text.
- Preserve the existing UX exactly (menus, the 6-step wizard, WACS-style
  filtering). Do not redesign prompts.
- Dates and log timestamps are ISO-8601. Code targets classic .NET-era C#/PS
  idioms the maintainer favors; if a modern PS7-only construct is used, keep it
  readable and obvious.

## What to avoid

- No GUI, no cross-platform code. Built-in deployment is IIS-only; non-IIS
  targets go through the optional `PostDeployHook` `.ps1`, not new core code.
- Do not duplicate binding/install logic between the wizard and the renewal
  runner — share `Private/Deploy.ps1`.
- Do not add `CONTRIBUTING`, `CODE_OF_CONDUCT`, badges, or boilerplate unless
  asked.
