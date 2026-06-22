# Rewrite PoshTUI as a PowerShell 7 module (greenfield, from no code)

**Labels:** `enhancement`, `rewrite`, `powershell`, `posh-acme`
**Assignee:** Copilot coding agent

## Summary

Rebuild PoshTUI from scratch as a proper PowerShell 7 module. PoshTUI is an
interactive, Simple-ACME/WACS-style text UI over Posh-ACME (4.x) for issuing and
renewing certificates against an internal ACME CA, with IIS binding integration.

The previous implementation was a single ~1,800-line script. Keep its **UX
verbatim** (see "UX contract"), discard its code, and fix the Posh-ACME
correctness defects listed below. The unattended renewal runner is specified
separately in **ISSUE-02-renewal-runner**; the two must share binding/install
helpers (no duplication).

## Goals

- Module layout with a public entry point `Start-PoshTui`; all menus and helpers
  as functions, unit-testable in isolation.
- Identical interactive UX to the reference (banner, main menu `N/M/B/S/T/Q`,
  the 6-step certificate wizard, the WACS-style site/host filtering).
- Correct Posh-ACME 4.x usage (see "Correctness requirements").
- Shared state model so the interactive admin and the SYSTEM scheduled task
  operate on the same accounts/orders/certs.
- Dry-Run and What-If modes preserved.

## Non-goals

- No GUI/WinForms. Terminal only.
- No cross-platform support: Windows + IIS + `IISAdministration` only.
- No **built-in** certificate deployment beyond IIS (no native Exchange/RDS/etc.
  in v1). Non-IIS targets are delegated to an optional user-supplied `.ps1`
  post-deploy hook (see "Deployment hook") — the tool does not ship deployment
  logic for them.
- Public CA support is incidental; the primary target is the internal ACME CA
  (`acme.fragt.root.local`). Let's Encrypt aliases stay available.

## Target environment / dependencies

- Windows Server 2019+ / Windows 10+, IIS installed.
- PowerShell **7.0+** (`#requires -Version 7.0`), run elevated
  (`#requires -RunAsAdministrator`).
- Modules: `Posh-ACME` (>= 4.x), `IISAdministration`. Installed `-Scope AllUsers`
  so SYSTEM and the admin load the same module path.
- Validation default: `WebSelfHost` (HTTP-01). DNS-01 plugins optional.

## Repository layout

```
/src
  PoshTui.psd1                 # manifest; RootModule = PoshTui.psm1; exports Start-PoshTui
  PoshTui.psm1                 # dot-sources Private/* and Public/*, exports public
  /Public
    Start-PoshTui.ps1          # main loop / dispatch
  /Private
    UI.ps1                     # banner, Write-Sep/Step/Ok/Warn/Err/Info, Read-* , Confirm-Prompt
    Config.ps1                 # load/save %ProgramData%\PoshTUI\config.json
    Bootstrap.ps1              # module/ACL assertions; sets POSHACME_HOME (no migration)
    Iis.ps1                    # Get-IISBindingsRaw, Get-IISSslBindings, Set/New-IISBinding*
    PoshAcme.ps1               # context helpers, server/account resolution, order listing
    Wizard.ps1                 # Invoke-NewCertificate (steps 1-6) + the three pickers
    Renewals.ps1               # Invoke-ManageRenewals, Invoke-RenewSingle, Invoke-RenewAll
    Accounts.ps1               # Invoke-AccountManagement, create/delete
    Tasks.ps1                  # Invoke-ManageScheduledTasks (registers PoshAcme-Renew.ps1)
    Deploy.ps1                 # SHARED: Install-PoshTuiCertificate, Update-IISCertificateBinding
/PoshAcme-Renew.ps1            # headless runner (ISSUE-02); imports the module, calls Deploy.ps1 helpers
/tests                         # Pester 5
/.github                       # Copilot skills (instructions + prompts)
README.md
```

`PoshAcme-Renew.ps1` lives at repo root next to a deployed copy of the module and
**reuses** `Install-PoshTuiCertificate` / `Update-IISCertificateBinding` from
`Private/Deploy.ps1` (exported as needed) so interactive and unattended rebinds
behave identically.

## Public surface

- `Start-PoshTui` — launches the menu loop. Optional switches: `-DryRun`,
  `-WhatIf`. No other exported commands required; everything else is private.

## UX contract (preserve exactly)

The reference script's interface is approved and must be reproduced. Do not
redesign menus or prompts.

**Banner + main menu**

```
  (ASCII "PoshTUI" banner)
  A Text User Interface for POSH ACME on Windows (PowerShell 7)
---------------------------------- Main menu ----------------------------------
  N: Create certificate (full options)
  M: Manage renewals (view / force-renew single / renew all / delete)
  B: Browse IIS bindings
  S: Manage ACME accounts
  T: Manage scheduled renewal tasks

  Q: Quit
```

**Certificate wizard (N)** — six steps, command-driven (single letters + args):

1. **Select IIS sites** — table `Selected / Id / Name / State`; `s <ids>` (e.g.
   `s 1,3`) or `s s` for all; `c` confirm; `x` cancel.
2. **Filter host headers** — table `Idx / Selected / SiteName / Protocol /
   IPAddress / Port / HostHeader` across selected sites (http+https, host header
   non-empty and not `*`); `p <pattern>` wildcard, `r <regex>`, `s <n>` toggle,
   `clear`, `c`, `x`. Show active filters.
3. **Choose CN** — list with `*` on the CN; `<number>` pick from list,
   `c <host>` custom CN, `c` confirm, `x`. Show "Final identifier list (CN first,
   then sorted)".
4. **ACME options** — read-only active context (Server / Account / Account key),
   `Validation Plugin`, **`Cert Store`** (corrected — see below); `v <plugin>`,
   `c`, `x`.
5. **Confirm & run** — echo Domains / CN / Server / Account / Validation / Cert
   Store and the equivalent PowerShell command, then `Proceed? [y/N]`.
6. **Bind IIS** — (a) re-point existing HTTPS bindings whose host header is in the
   identifier set; (b) offer to create new HTTPS bindings (SNI, port 443 default)
   for HTTP-only host headers. Summarize OK/Failed counts.

**M / B / S / T** behave as in the reference (list + single-letter actions). All
state-changing commands prompt for confirmation and respect Dry-Run/What-If.

> One change vs. the reference: **Step 4 must label the cert store truthfully**
> (see Correctness #3). Everything else is unchanged.

## Correctness requirements (Posh-ACME 4.x)

These are the defects in the old code. Each is mandatory. Details and do/don't
snippets are in `.github/instructions/posh-acme.instructions.md`.

1. **`Submit-Renewal -AllOrders`, not `-RenewAll`.** `-RenewAll` is not a valid
   parameter. Batch renewal uses `-AllOrders`; force with `-Force`.
2. **`-Plugin`, not `-DnsPlugin`.** `DnsPlugin` was removed from
   `New-PACertificate` in 4.x. `WebSelfHost` is an HTTP-01 plugin and is passed
   via `-Plugin WebSelfHost`.
3. **Cert store: stop claiming `-Install` targets WebHosting — it targets
   `LocalMachine\My`.** Choose one model and label the UI to match:
   - Issue without `-Install`, then
     `Get-PACertificate | Install-PACertificate -StoreLocation LocalMachine -StoreName WebHosting`,
     and bind with `StoreName = WebHosting`; **or**
   - Use `-Install` (→ `My`) and bind with `StoreName = My`.
   Recommended: **WebHosting via `Install-PACertificate`** (per-site key
   isolation). The store used for issuance, the store written to the binding, and
   the Step-4 label must all be the same value, sourced from one config key.
4. **DPAPI vs. shared profile.** Secure plugin args (DNS plugins) are
   DPAPI-encrypted and tied to the user+machine; they will **not** decrypt when
   the SYSTEM scheduled task runs. For any account that stores secure plugin args,
   call `Set-PAAccount -UseAltPluginEncryption` once (portable AES) so the shared
   `POSHACME_HOME` works across identities. Surface this in account management:
   warn when an account has secure plugin args but alt encryption is off.
   (`WebSelfHost` has no secure args, so this is a no-op for the default path —
   but the rewrite must still set it for DNS accounts and document it.)
5. **Date handling.** `RenewAfter` / `NotAfter` may be `DateTime` **or** ISO-8601
   strings depending on version. Provide a `Format-PADate` / `ConvertTo-DateTime`
   pair (as in the reference) and never call `.ToString('fmt')` on a raw value.
   Display all dates ISO-8601 (`yyyy-MM-dd HH:mm`).
6. **Invalid-order cleanup (keep).** Before issuing, detect orders in `Invalid`
   state whose identifiers overlap the request and offer to `Remove-PAOrder` them;
   refuse to renew an `Invalid` order (delete + re-issue path).
7. **Server identifier resolution (keep).** `Set-PAServer` accepts a built-in
   alias or a full `https://` URL only; for custom-named servers pass the
   directory URL (`.location`). Keep the `Resolve-PAServerArg`/`ConvertTo-PAServerArg`
   logic.

## Certificate store & binding model

- Single config key `CertStore` (default `WebHosting`) drives issuance import,
  binding `StoreName`, and the Step-4 label.
- Binding writes go through `Set-IISBindingCertificate` (re-point existing) and
  `New-IISHttpsBinding` (create, SNI on when a host header is present), both using
  `Microsoft.Web.Administration` via `Get-IISServerManager` and committing once.
- Thumbprint ↔ `byte[]` conversion centralized in one helper; never inline it
  twice.

## Deployment hook (non-IIS targets)

IIS rebinding is built in. Everything else (RDS, Exchange, a reverse proxy, a
file drop, etc.) is delegated to an **optional** user-supplied PowerShell script —
the tool ships no logic for those targets.

- Config key `PostDeployHook` (string; path to a `.ps1`; empty/absent = disabled).
- After a certificate is **successfully issued** (Step 6) and after **each
  successfully renewed** certificate (ISSUE-02), if the hook is set, invoke it in
  the current session with the call operator and pass the cert object:
  ```powershell
  & $PostDeployHook -Certificate $cert -Thumbprint $cert.Thumbprint -StoreName $CertStore
  ```
  `$cert` is the `PACertificate` object from `New-PACertificate`/`Submit-Renewal`
  (carries `Thumbprint`, `AllSANs`, file paths). Hook authors can use Posh-ACME's
  sister module `Posh-ACME.Deploy` (e.g. `Set-IISCertificate`, `Set-RDSHCertificate`)
  or roll their own.
- Hook authors should define a matching param block; the contract is
  `-Certificate <object>`, `-Thumbprint <string>`, `-StoreName <string>` (add more
  only if you also pass them).
- **Isolation:** wrap the call in `try/catch`; a hook failure is logged
  (`Write-Err` / event) and must not roll back the cert or abort other certs.
- **Dry-Run / What-If:** in Dry-Run print the hook invocation and run nothing; in
  What-If forward `-WhatIf` if the hook supports it (best-effort, same pattern as
  `Invoke-PAAction`).
- The same hook path is used by `PoshAcme-Renew.ps1` (ISSUE-02), so a renewal
  deploys to the same non-IIS targets unattended.

## State & identity model

- `%ProgramData%\PoshTUI\` holds `config.json` and the shared ACME store
  (`%ProgramData%\PoshTUI\ACME`). ACL: Administrators + SYSTEM Full, Users
  ReadAndExecute.
- The bootstrap sets `POSHACME_HOME` to `%ProgramData%\PoshTUI\ACME`
  **directly in the script** — both machine-wide (so the SYSTEM scheduled task
  sees it) and for the current process (so no relaunch is needed). It is set
  unconditionally to that fixed path; there is no scope knob and no `%APPDATA%`
  option. Use `$env:ProgramData` to build the path, not a hardcoded `C:\`.

  ```powershell
  function Initialize-PoshTuiHome {
      $root = Join-Path $env:ProgramData 'PoshTUI'
      $acmeHome = Join-Path $root 'ACME'
      New-Item -ItemType Directory -Path $acmeHome -Force | Out-Null
      # ACL: Administrators + SYSTEM = FullControl, Users = ReadAndExecute (set on $root)
      Set-PoshTuiAcl -Path $root
      [Environment]::SetEnvironmentVariable('POSHACME_HOME', $acmeHome, 'Machine')
      $env:POSHACME_HOME = $acmeHome          # current process, no relaunch
      Import-Module Posh-ACME -Force      # pick up the new location
  }
  ```
- **No migration logic.** Do not detect, copy, or import any pre-existing
  `~\.poshacme` / `%LOCALAPPDATA%\Posh-ACME` store. The bootstrap only ensures the
  directory + ACL exist and points `POSHACME_HOME` at it; whatever is already in
  that path is used as-is. If a user has prior data elsewhere, moving it is a
  manual, out-of-band step — the tool never touches it.
- Scheduled renewal runs as **SYSTEM**; the machine-wide `POSHACME_HOME` above
  (combined with #4) is what lets unattended renewal see the same
  accounts/orders/certs.

## Validation plugins

- Default `WebSelfHost`. No plugin args needed for port 80 / 120 s; expose
  `WSHPort` / `WSHTimeout` only if the user overrides.
- **Redirect landmine:** if any selected site has an HTTP→HTTPS redirect (URL
  Rewrite / `httpRedirect`), it will 301 the ACME challenge and validation fails.
  The wizard must warn when a selected HTTP binding's site has a redirect rule and
  suggest excluding `/.well-known/acme-challenge/` (or using a DNS plugin).
- DNS-01 plugins are supported via `-Plugin <name> -PluginArgs @{...}`; prompt for
  args and apply #4 (alt encryption).

## Dry-Run / What-If

- `Invoke-PAAction` wrapper: Dry-Run prints the equivalent command and executes
  nothing; What-If passes `-WhatIf` to ShouldProcess-aware cmdlets. Read-only
  state changes (`Set-PAServer`, `Set-PAAccount`) may run during Dry-Run **only**
  to make displayed commands/lookups accurate, and this must be stated on screen.

## Error handling & logging

- `Set-StrictMode -Version Latest`; `$ErrorActionPreference = 'Stop'` at module
  scope; per-action `try/catch` with `Write-Err` and continue the menu loop.
- All state-changing private functions: `[CmdletBinding(SupportsShouldProcess)]`.
- A shared `Write-PoshTuiLog` appends ISO-8601 lines to
  `%ProgramData%\PoshTUI\renewal.log` (consumed by the T-menu log viewer and by
  the renewal runner).

## Config schema (`config.json`)

```jsonc
{
  "ACMEServer": "acme.fragt.root.local",   // alias or directory URL
  "ContactEmail": "",
  "ValidationPlugin": "WebSelfHost",
  "DnsPluginArgs": {},
  "CertStore": "WebHosting",               // drives import + binding + label
  "PostDeployHook": "",                     // optional .ps1 for non-IIS deployment; empty = off
  "RenewalDaysBefore": 30
}
```

(Key type/length are read from the active account, not stored here.)

## Testing & CI

- Pester 5 unit tests with `Posh-ACME` and `IISAdministration` mocked: identifier
  ordering (CN first), host-filter (`p`/`r`/`s`/`clear`), thumbprint↔byte
  round-trip, `Resolve-PAServerArg`, `Format-PADate` for both DateTime and
  ISO-8601 inputs, invalid-order detection.
- `Invoke-ScriptAnalyzer -Path ./src -Recurse` clean (no errors/warnings).
- GitHub Actions on `windows-latest`: install modules, run analyzer + Pester.
- Integration (manual / self-hosted): against the internal ACME CA or a Pebble
  instance, with `Set-PAServer -SkipCertificateCheck` for self-signed dev CAs.

## Acceptance criteria

- [ ] `Import-Module ./src/PoshTui.psd1; Start-PoshTui` launches; UX matches the
      contract above.
- [ ] No occurrence of `-RenewAll` or `-DnsPlugin` anywhere; `-AllOrders` and
      `-Plugin` used instead.
- [ ] Issuance, binding `StoreName`, and the Step-4 label all read from
      `CertStore`; cert ends up in that store and bindings resolve.
- [ ] Accounts with secure plugin args are switched to alt (AES) encryption and
      the UI warns when they are not.
- [ ] Dates render ISO-8601; no crash on string-typed `RenewAfter`/`NotAfter`.
- [ ] Invalid-order detection/cleanup works; `Invalid` orders cannot be renewed.
- [ ] Dry-Run executes nothing destructive; What-If forwarded where supported.
- [ ] PSScriptAnalyzer clean; Pester suite green in CI.
- [ ] Optional `PostDeployHook` `.ps1` is invoked after issuance and after each
      renewal with the `PACertificate` object; failures are isolated/logged, and it
      honors Dry-Run/What-If. No built-in non-IIS deployment exists otherwise.
- [ ] Bootstrap sets `POSHACME_HOME` to `%ProgramData%\PoshTUI\ACME` (machine +
      process) in the script, fixed path, no knob. **No data-migration/copy/import
      of any prior store** (`~\.poshacme`, `%LOCALAPPDATA%\Posh-ACME`, etc.).
- [ ] `Install-PoshTuiCertificate` / `Update-IISCertificateBinding` are shared
      with `PoshAcme-Renew.ps1` (ISSUE-02), not duplicated.

## Future (out of scope for v1)

- Central Certificate Store (CCS/UNC) for IIS farms.
- gMSA run-as for the scheduled task instead of SYSTEM.
- SQL audit sink for issuance/renewal events.
