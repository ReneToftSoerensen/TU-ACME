# Add unattended renewal runner `PoshAcme-Renew.ps1` + scheduled-task contract

**Labels:** `enhancement`, `renewal`, `scheduled-task`, `posh-acme`
**Assignee:** Copilot coding agent
**Depends on:** ISSUE-01 (shares `Private/Deploy.ps1` helpers)

## Summary

The T menu ("Manage scheduled renewal tasks") registers a Windows Scheduled Task
that runs `pwsh.exe -File PoshAcme-Renew.ps1 [-ServerName ...] [-AccountID ...]`,
but **that script has never existed**. This issue adds it: a headless,
non-interactive renewal runner that renews due Posh-ACME orders, re-installs the
new certs, and re-points the affected IIS HTTPS bindings — all without a console.

It must reuse the binding/install helpers from ISSUE-01
(`Install-PoshTuiCertificate`, `Update-IISCertificateBinding`) so unattended and
interactive renewals behave identically.

## Requirements

As a standalone script (not the module), it declares the same prerequisites:
```powershell
#requires -Version 7.0
#requires -RunAsAdministrator
#requires -Modules Posh-ACME, IISAdministration
```
Elevation is required for `Install-PACertificate` and IIS binding edits; the
SYSTEM scheduled-task principal satisfies `-RunAsAdministrator`, and the
declaration still gives a clear failure if anyone runs it non-elevated by hand.

## Goals

- One self-contained entry script at repo root, runnable as
  `pwsh -NoProfile -ExecutionPolicy Bypass -File .\PoshAcme-Renew.ps1`.
- Renew only due orders by default; optional force; optional scoping to a single
  server/account.
- Deterministic rebind of IIS HTTPS bindings to the renewed certificate.
- File + Windows Event Log output; meaningful exit codes for Task Scheduler.
- Safe to run under **SYSTEM** against the shared `POSHACME_HOME`.

## Non-goals

- No interactive prompts, no `Read-Host`, no `Write-Host` UI. Logging only.
- No new validation logic — renewal reuses each order's stored plugin/args.

## Invocation contract (must match what the T menu registers)

```
PoshAcme-Renew.ps1
  [-ServerName <string>]    # alias or directory URL; resolved like the TUI. Omit = all servers.
  [-AccountID  <string>]    # restrict to one account. Omit = all accounts on the server(s).
  [-Force]                  # renew regardless of RenewAfter (maps to Submit-Renewal -Force)
  [-CertStore  <string>]    # default 'WebHosting'; overrides config
  [-PostDeployHook <string>] # optional .ps1 for non-IIS deploy; overrides config; empty = off
  [-LogPath    <string>]    # default %ProgramData%\PoshTUI\renewal.log
  [-WhatIf]                 # no changes; log intended actions
```

`Tasks.ps1` in ISSUE-01 must generate exactly this parameter line. Keep the
`-ServerName`/`-AccountID` names stable — they are the integration seam.

### Exit codes

- `0` — success, including "nothing was due" (no-op is success).
- `1` — one or more renewals failed, or one or more rebinds failed (partial).
- `2` — fatal/setup error (module/`POSHACME_HOME` unavailable, no accounts, etc.).

Task Scheduler "Last run result" then reflects health; the T-menu list already
maps `0 = Success`.

## Identity & state

- Designed to run as **SYSTEM**, highest privileges (Task Scheduler principal set
  by ISSUE-01).
- Resolve `POSHACME_HOME` from the machine environment (set by the TUI bootstrap);
  if absent, fall back to `C:\ProgramData\PoshTUI\ACME` and log a warning.
- **DPAPI:** orders that carry secure plugin args (DNS plugins) must have been
  switched to alt (AES) encryption (`Set-PAAccount -UseAltPluginEncryption`) by the
  TUI, or `Submit-Renewal` will fail under SYSTEM. The runner must detect a
  decryption failure and log a clear remediation message ("run account management
  in PoshTUI to enable portable encryption"), not a raw stack trace.

## Algorithm

1. Setup: import the `PoshTui` module (from the deployed module path or
   `./src/PoshTui.psd1`), `Set-StrictMode`, resolve `POSHACME_HOME`, open the log.
2. Enumerate target (server, account) tuples (reuse `Get-AllPAAccounts`),
   honoring `-ServerName`/`-AccountID`.
3. For each account: activate server+account, then **snapshot** the current IIS
   HTTPS binding → thumbprint map (for logging/diagnostics).
4. Renew: `Submit-Renewal -AllOrders [-Force]`. It returns `PACertificate` objects
   **only for orders actually renewed** — iterate those; if none, log "no orders
   due" and continue.
5. For each renewed cert:
   a. `Install-PoshTuiCertificate` into `CertStore` (reuse ISSUE-01 helper:
      `Get-PACertificate <name> | Install-PACertificate -StoreLocation LocalMachine -StoreName <CertStore>`).
   b. **Rebind by SAN match (preferred for headless):** for each name in
      `$cert.AllSANs`, find IIS HTTPS bindings whose `HostHeader` equals that name
      and re-point them to `$cert.Thumbprint` via `Update-IISCertificateBinding`.
      Rationale: headless runs may not know the *old* thumbprint reliably; matching
      on host header is robust and idempotent (skip if already on the new
      thumbprint). Fall back to old-thumbprint match using the snapshot when a SAN
      yields no host-header binding.
   c. Log each rebind (site / binding / old→new thumbprint).
   d. **Post-deploy hook (non-IIS):** if `PostDeployHook` (config / `-PostDeployHook`)
      is set, invoke it for this cert —
      `& $PostDeployHook -Certificate $cert -Thumbprint $cert.Thumbprint -StoreName $CertStore`.
      Same contract as ISSUE-01. Wrap in `try/catch`; a hook failure is logged and
      counts toward the partial-failure exit code (`1`) but must not abort the
      other certs. Honors `-WhatIf` (best-effort).
6. Aggregate results; set exit code; flush log and Event Log.

> Do **not** rebind by re-running the whole `New-PACertificate` flow. Renewal =
> `Submit-Renewal`; deployment is a separate, local step.

## Rebind/install reuse

`Install-PoshTuiCertificate` and `Update-IISCertificateBinding` are defined once in
ISSUE-01 (`Private/Deploy.ps1`) and called by both the wizard (Step 6) and this
runner. If they are not exported, the runner imports the module and calls them via
the module scope; do not copy-paste the binding logic.

## Logging

- **File:** append ISO-8601 lines to `-LogPath`
  (`2026-06-22T03:00:11+02:00 [INFO] ...`). One run = a delimited block with a
  start/stop banner and a summary (`renewed=N rebound=M failed=K`).
- **Windows Event Log:** ensure source `PoshTUI` exists
  (`New-EventLog -LogName Application -Source PoshTUI` if missing); write one
  Information event on success, Warning on partial, Error on fatal — so existing
  monitoring/alerting can subscribe.
- The T-menu log viewer (`Show-RenewalLog`) reads `-LogPath`; keep the default
  path aligned.

## Idempotency / ARI / Force

- Re-running when nothing is due is a clean no-op (exit 0).
- Honor Posh-ACME's `RenewAfter` (ARI-aware) by default; `-Force` bypasses it via
  `Submit-Renewal -Force`.
- Rebinds are idempotent: skip when the binding already carries the new thumbprint.

## Failure isolation

- Wrap per-account and per-cert work in `try/catch`; a failure for one cert must
  not abort the others. Collect failures and reflect them in the exit code and the
  summary line.

## Security considerations

- Runs elevated as SYSTEM (required for `Install-PACertificate` and IIS binding
  edits).
- If any order uses `WebSelfHost`, port 80 must be answerable during validation;
  http.sys path routing generally lets the listener coexist with running IIS
  sites, but an HTTP→HTTPS redirect on the site will 301 the challenge — flag this
  in docs and prefer DNS-01 for sites with forced HTTPS.

## Testing

- Pester unit tests (mock `Submit-Renewal` to return crafted `PACertificate`
  objects, mock IIS helpers): SAN-match rebind, old-thumbprint fallback,
  nothing-due no-op, partial-failure exit code, alt-encryption failure path.
- Manual integration as SYSTEM via `schtasks /run` against the internal ACME CA /
  Pebble.

## Acceptance criteria

- [ ] `PoshAcme-Renew.ps1` runs headless under SYSTEM with the exact param names
      `-ServerName` / `-AccountID` registered by the T menu.
- [ ] Renews only due orders by default; `-Force` overrides; nothing-due = exit 0.
- [ ] Renewed certs are imported to `CertStore` and the matching IIS HTTPS
      bindings are re-pointed (SAN match, thumbprint fallback), idempotently.
- [ ] Binding/install logic is the shared ISSUE-01 helpers (no duplication).
- [ ] If `PostDeployHook` is set, it runs per renewed cert with the `PACertificate`
      object; a hook failure is logged, contributes to exit `1`, and does not abort
      other certs.
- [ ] File log (ISO-8601) + Event Log entries written; exit codes `0/1/2` as
      specified.
- [ ] Decryption failure under SYSTEM produces a clear "enable portable
      encryption" message, not a stack trace.
- [ ] Pester suite green; PSScriptAnalyzer clean.
