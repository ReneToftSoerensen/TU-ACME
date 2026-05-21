---
name: posh-acme-expert
description: Practical Posh-ACME v4 knowledge — function shapes, config layout, gotchas (server isolation, DPAPI, no -PostScript hook). Use when writing or reviewing PowerShell that calls Get/New/Set-PA*, Submit-Renewal, or wraps the Posh-ACME module.
argument-hint: "[check|fix]"
---

## Activation triggers
- The code calls any `*-PA*` cmdlet (`New-PACertificate`, `Submit-Renewal`, `Get-PAAccount`, etc.).
- The user asks about ACME certificate ordering, renewal, DNS-01 / HTTP-01 challenges, or Let's Encrypt automation in PowerShell.
- A `.psm1`/`.ps1` file imports `Posh-ACME` or sets `POSHACME_HOME`.

## Verified Posh-ACME v4 surface (from FunctionsToExport in the v4 manifest)

**Account / server / config:**
`Get-PAServer`, `Set-PAServer`, `Remove-PAServer`,
`Get-PAAccount`, `New-PAAccount`, `Set-PAAccount`, `Remove-PAAccount`, `Export-PAAccountKey`.

**Orders / certificates:**
`New-PACertificate`, `Get-PACertificate`, `Install-PACertificate`, `Revoke-PACertificate`,
`New-PAOrder`, `Get-PAOrder`, `Set-PAOrder`, `Remove-PAOrder`,
`Submit-OrderFinalize`, `Complete-PAOrder`, `Submit-Renewal`.

**Plugins / challenges:**
`Get-PAPlugin`, `Get-PAPluginArgs`,
`Publish-Challenge`, `Unpublish-Challenge`, `Publish-DnsPersistChallenge`, `Unpublish-DnsPersistChallenge`,
`Save-Challenge`, `Submit-ChallengeValidation`, `Send-ChallengeAck`,
`Invoke-HttpChallengeListener`,
`New-PAAuthorization`, `Get-PAAuthorization`, `Revoke-PAAuthorization`.

**Misc:** `Get-PAProfile`, `Get-KeyAuthorization`, `Get-DnsAcctLabel`.

**Functions that DO NOT exist (despite older guidance):**
- `Set-PAConfig` / `Get-PAConfig` — no such function in v4. There is **no native `-PostScript` post-renewal hook.** If you need one, wrap `Submit-Renewal` in your own script (compare `Get-PACertificate -List` before/after, act on thumbprint changes).

## Critical patterns

1. **Set the server first.** `Set-PAServer LE_PROD` (or `LE_STAGE` for testing). All accounts/orders/certs are stored under `(Get-PAServer).Folder` — switching the server changes which accounts/orders are visible. Accounts on `LE_PROD` are invisible from `LE_STAGE` and vice versa.
2. **`-AcceptTOS` is mandatory for the first account.** Both `New-PACertificate` and `New-PAAccount` error out if no account exists and `-AcceptTOS` is missing. Pass it on first call; it's idempotent thereafter.
3. **`New-PACertificate` is end-to-end.** It creates an account if needed, an order, runs plugin challenges, finalizes, downloads artefacts, and (with `-Install`) imports to `LocalMachine\My`. Required for a fresh cert: `-Domain`, `-AcceptTOS` (first time), `-Plugin`, `-PluginArgs`.
4. **`PluginArgs` keys are plugin-specific.** Discover with `Get-PAPlugin <Name> -Params`. The hashtable is persisted per-order and reused by `Submit-Renewal`.
5. **`Submit-Renewal` re-runs `New-PACertificate` with the saved params.** Renewal window is `order.RenewAfter`; `-Force` bypasses it. Manual-DNS orders are skipped unless `-NoSkipManualDns`. **There is no user-defined hook** — write a wrapper if you need one.
6. **Switching active account:** `Set-PAAccount -ID <id>` where `<id>` is the alphanumeric ID from `Get-PAAccount -List` (NOT the contact email).
7. **Wildcards (`*.example.com`) require DNS-01.** HTTP-01 cannot validate wildcards.
8. **Cert object property names:** `Get-PACertificate` returns `Subject, NotBefore, NotAfter, KeyLength, Thumbprint, ARIId, Serial, AllSANs, CertFile, KeyFile, ChainFile, FullChainFile, PfxFile, PfxFullChain, CSR, PfxPass`. Note: `AllSANs` (not `SANs`). `MainDomain` lives on the **order**, not the certificate.

## `New-PACertificate` defaults (v4.32)

| Parameter | Default |
|---|---|
| `AccountKeyLength` | `ec-256` |
| `CertKeyLength` | `2048` |
| `DirectoryUrl` | `LE_PROD` |
| `DnsSleep` | `120` seconds |
| `ValidationTimeout` | `60` seconds |
| `PfxPass` | `'poshacme'` (literal string!) |

Override `PfxPass` or your PFX is effectively unprotected. `-PfxPassSecure` takes a `SecureString`.

## `Set-PAServer` shortcuts

`LE_PROD`, `LE_STAGE`, `ZEROSSL_PROD`, `GOOGLE_PROD`, `GOOGLE_STAGE`, `SSLCOM_RSA`, `SSLCOM_ECC`, `ACTALIS_PROD`. For others (BuyPass, internal CAs like step-ca / Smallstep / Caddy CA), pass the full ACME directory URL.

## Config layout on disk

| Platform | Default path |
|---|---|
| Windows (PS 5.1 + pwsh 7) | `$env:LOCALAPPDATA\Posh-ACME` |
| Linux | `$env:HOME/.config/Posh-ACME` |
| macOS | `$env:HOME/Library/Preferences/Posh-ACME` |

Override with `$env:POSHACME_HOME` (path must exist or it warns and falls back).

Layout: `<root>/<server-dir>/<account-id>/<order-name>/`. Active selection tracked in `current-server.txt`, `current-account.txt`, `current-order.txt`. `(Get-PAServer).Folder` returns the active server's path.

**Headless / Task Scheduler implication:** SYSTEM has its own `LOCALAPPDATA` (typically `C:\Windows\System32\config\systemprofile\AppData\Local`), NOT the admin user's. A renewal task running as SYSTEM will see no orders unless you either: (a) point both `POSHACME_HOME` at a shared path (`$env:ProgramData\Posh-ACME`), or (b) create the account under SYSTEM (`psexec -s`).

## Gotchas

- **`New-PAAccount` returns the account in v4.32+ — if you see `$null`, it's a swallowed non-terminating error** (CA rejection, missing `-AcceptTOS`, DPAPI failure). Capture with `-ErrorAction Stop` and then verify with `Get-PAAccount -List | Where-Object Contact -contains "mailto:$email"`. Don't rely solely on the return value.

- **DPAPI is per-user, per-machine.** Account keys encrypted at rest (default) cannot be read by a different user account, including SYSTEM. For scheduled tasks running under SYSTEM either create the account under SYSTEM (`psexec -s`) or pass `-UseAltPluginEncryption` (portable AES) at account creation time.

- **`DnsSleep` defaults to 120s — too short for slow DNS providers.** Bump to 300–600 for Route53 multi-region, GoDaddy, or self-hosted BIND. Reducing it below the plugin's real propagation time is the most common cause of `urn:ietf:params:acme:error:dns` failures.

- **`PfxPass` defaults to the literal string `'poshacme'`.** Override or document the override.

- **Rate-limit signals (Let's Encrypt):**
  - `urn:ietf:params:acme:error:rateLimited` — terminal until window clears (hours). Switch to `LE_STAGE` for testing.
  - `urn:ietf:params:acme:error:serverInternal` or `Invoke-WebRequest` failures — transient, retry with backoff.

- **`-Install` is Windows-only** and requires elevation. It writes to `LocalMachine\My`. There is no `CurrentUser` option.

- **PS 5.1 UTF-8 encoding diverges from pwsh 7.** Posh-ACME writes its own files; if you pipe its output to disk yourself, always specify `-Encoding UTF8` so the result is consistent across platforms.

- **`Submit-Renewal -Force` only overrides `RenewAfter`.** It does NOT override the manual-DNS skip and does NOT override the null-plugin skip. Pass `-NoSkipManualDns` for manual orders.

- **HTTP-01 plugin choice:** `WebRoot` (write file to a path the web server serves) is the most universal. `WebSelfHost` (start a temporary listener on :80) needs the port free. Posh-ACME has no built-in IIS HTTP-01 plugin — use `WebRoot` against `C:\inetpub\wwwroot`.

- **ACME-DNS** (CNAME-delegated DNS-01) requires a one-time CNAME setup in the real DNS zone; subsequent renewals don't need DNS access. Use when the real DNS doesn't have an API (or you don't want to give Posh-ACME those credentials).

## TU-ACME-specific notes

- **`Set-PAConfig -PostScript` does not work.** Anywhere TU-ACME calls it (currently `Invoke-IISMenu.ps1:220`, header comment in `Posh-ACME-IIS-Plugin.ps1`, INSTALL.md, CLAUDE.md, SMOKE-TEST.md) will fail at runtime with `The term 'Set-PAConfig' is not recognized`. To get a post-renewal hook: write a wrapper around `Submit-Renewal` that diffs `Get-PACertificate -List` thumbprints before/after, then performs the IIS rebind in TU-ACME's own code. The standalone script (`Posh-ACME-IIS-Plugin.ps1`) needs to be invoked from that wrapper, not registered with Posh-ACME.

- **Initialize-PALogging's proxy list contains `Set-PAConfig`** — harmless (`Get-Command -Module Posh-ACME -Name Set-PAConfig` returns `$null`, the proxy is skipped), but the list should be updated to reflect the real surface.

- **For the dashboard (UC-4.1):** the cert object exposes `AllSANs` (array), not `SANs`. There is no `MainDomain` on the cert — read it from the order via `Get-PAOrder`. Color by `(NotAfter - (Get-Date)).TotalDays`. `Thumbprint` is the join key to `Get-WebBinding`'s `certificateHash`.

- **For headless renewal (UC-5.x):** set `$env:POSHACME_HOME = "$env:ProgramData\TU-ACME\Posh-ACME"` in the Scheduled Task action so SYSTEM and the admin who set things up see the same store. Create the initial account under whichever identity will run the task, or pass `-UseAltPluginEncryption`.

- **Source-of-truth principle holds:** never cache Posh-ACME state in TU-ACME's `config.json` beyond a pointer (e.g. last-used server shortcut). Always call `Get-PACertificate -List` / `Get-PAAccount -List` fresh.
