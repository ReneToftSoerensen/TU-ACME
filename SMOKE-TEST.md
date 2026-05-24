# TU-ACME Smoke Test

This is the manual checklist an operator runs after deploying TU-ACME to a new host (or after a version bump). Work top to bottom; every box should pass before the install is considered green.

## 1. Fresh install and first-run wizard

- [ ] `%ProgramData%\TU-ACME\` does not exist before the run.
- [ ] `Import-Module TU-ACME; Start-TUACME` prompts for production URL, staging URL, and contact email.
- [ ] After the wizard, both accounts exist in the Posh-ACME store at `%ProgramData%\Posh-ACME\` (one per server).
- [ ] `config.json` is written under `%ProgramData%\TU-ACME\` with the URLs and email in plaintext.

## 2. Restart does not re-prompt

- [ ] Close PowerShell, reopen, run `Start-TUACME` again. The main menu appears immediately. No wizard. No prompts.

## 3. Menu alignment over 100 columns

- [ ] Resize the console to at least 100 columns wide and re-open the main menu. Title, borders, and selector caret line up. Nothing wraps or shears.

## 4. Order a production certificate

- [ ] From the main menu, order a real certificate for a test hostname.
- [ ] Posh-ACME completes the order against the **production** account.
- [ ] The certificate appears in the dashboard with the correct hostname and expiry.

## 5. Dry-run order uses staging, leaves prod active

- [ ] Trigger a dry-run order from the menu.
- [ ] During the call, `Get-PAServer` returns the staging URL. Confirm by stepping through or by tail of the log.
- [ ] After the dry-run returns, `Get-PAServer` is back to the production URL. The dry-run did not leave staging selected.

## 6. Dashboard hides dry-runs by default

- [ ] Open the certificate dashboard. Only production certificates appear; the staging dry-run from step 5 is hidden.
- [ ] Press `d`. The dry-run row now shows alongside production rows, clearly marked as staging.
- [ ] Press `d` again. The view collapses back to production-only.

## 7. Background renewal as SYSTEM uses prod

- [ ] The scheduled task created in step 9 runs under SYSTEM.
- [ ] Force a run (`Start-ScheduledTask`) and inspect the log: the renewal call targets the **production** account, not staging.
- [ ] Posh-ACME store at `%ProgramData%\Posh-ACME\` is the one SYSTEM sees (no per-user redirect).

## 8. IIS rebind

- [ ] From the certificate menu, rebind an existing IIS HTTPS binding to a freshly issued cert.
- [ ] `Get-WebBinding` confirms the new thumbprint is bound on port 443.

## 9. Scheduled task overwrite prompt

- [ ] Run the scheduled-task installer twice. On the second run, TU-ACME asks whether to overwrite the existing task instead of silently duplicating it.

## 10. SMTP configuration and DPAPI-encrypted credentials

- [ ] Configure SMTP from the menu. The password prompt uses `Read-Host -AsSecureString`.
- [ ] The stored credential file under `%ProgramData%\TU-ACME\` is DPAPI-encrypted (not plaintext).
- [ ] Sending a test mail succeeds and the message body shows the current version.

## 11. Log viewer

- [ ] The log viewer renders recent events from the TU-ACME Windows Event Log source, filterable by level.

## 12. Repo hygiene

- [ ] `git grep 'Invoke-AccountMenu'` returns no matches. The Accounts menu is gone for good in v2.
- [ ] `git grep 'Set-PAServer'` only matches files under `TU-ACME/Private/Bootstrap/`. No other module file may call it directly.
