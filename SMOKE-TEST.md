# Smoke Test - Windows + PowerShell 5.1

Manual pre-release checklist. Run on a real Windows host with `powershell.exe` (not `pwsh`) before tagging a release.

## Environment

- **OS:** Windows Server 2019/2022 or Windows 10/11
- **PowerShell:** 5.1 (`$PSVersionTable.PSVersion`)
- **Privileges:** Administrator (required for IIS, Scheduled Tasks, event log source creation)
- **Console:** at least 100 columns wide for the dashboard test
- **Network:** outbound to Let's Encrypt staging + your DNS provider's API

```powershell
# Install module from this branch
$dest = "$env:ProgramFiles\WindowsPowerShell\Modules\TU-ACME"
Copy-Item -Recurse -Force .\TU-ACME $dest
Import-Module TU-ACME -Force
$PSVersionTable.PSVersion    # must be 5.1.x
```

Switch Posh-ACME to staging so the certificate tests do not burn production rate-limit quota:

```powershell
Set-PAServer LE_STAGE
```

## 1. Menu alignment on a wide terminal (>100 cols)

The original task — verify menu input stays anchored at column 0 even when the terminal is wider than 80 cols.

```powershell
# Resize the console to ~140 cols, then:
Start-TUACME
```

Check:
- [ ] Main menu title `TU-ACME v0.5.4 - Certificate Management` renders at column ~2 (the two-space indent), not centered
- [ ] All option lines start at column 2, not centered or right-aligned
- [ ] After hitting `/` to search, the search prompt and input cursor sit at column 2
- [ ] When you press a hotkey digit or arrow to navigate, the highlighted row's text stays left-anchored
- [ ] After hitting Esc from a sub-menu, your next Write-Host appears at column 0 (no leftover cursor offset)

## 2. Certificate order (staging)

Use a domain you control with DNS API access (Cloudflare/Route53/etc.).

```powershell
Start-TUACME
# Menu: Certificates -> Order new certificate
# Domain: pick a test subdomain
# Plugin: pick your DNS plugin (or Manual)
# DnsSleep: blank (defaults to 120)
# At "Confirm order? (y/N)" - press Enter (blank).
```

Check:
- [ ] Enter on `(y/N)` returns to the menu without ordering — the `-Default $false` change should block the destructive default
- [ ] Re-run, this time type `Y` at the confirm prompt → spinner appears, order proceeds
- [ ] On success, prints `Certificate ordered!` with domain/expiry/thumbprint
- [ ] On rate-limit error, shows the staging tip
- [ ] On DNS error, shows the DnsSleep tip
- [ ] `Get-PACertificate -List` shows the new cert

## 3. Certificate dashboard (wide terminal)

```powershell
Start-TUACME
# Main menu -> Certificate dashboard
```

Check:
- [ ] Table renders with all five columns visible at >100 cols
- [ ] Color coding: green (>30 days), yellow (1-30), red (expired)
- [ ] Arrow up/down highlights one row at a time, no flicker
- [ ] Press Enter on a row → details page shows all 12 fields
- [ ] On details page: press `r` AND press `R` → both trigger renewal (case-insensitive fix)
- [ ] Press `e` AND `E` → both open Export menu
- [ ] Press Esc → returns to dashboard

## 4. Renewal (background script)

Test the standalone renewal script directly (without scheduling):

```powershell
# Run the same script Task Scheduler would launch
powershell.exe -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass `
    -File "$env:ProgramFiles\WindowsPowerShell\Modules\TU-ACME\Scripts\Invoke-RenewalBackground.ps1"

# Check the Application event log for TU-ACME entries
Get-EventLog -LogName Application -Source TU-ACME -Newest 5 |
    Format-Table TimeGenerated, EventID, EntryType, Message -Wrap
```

Check:
- [ ] Exit code is 0 (success or no-renewal-needed)
- [ ] EventLog shows EventId 1001 with `Certificate renewed` or `No certificates required renewal`
- [ ] Force a failure: temporarily rename the Posh-ACME module folder, re-run, confirm:
  - [ ] Exit code is 1
  - [ ] EventLog shows EventId 3001 with `Posh-ACME not available`
- [ ] If SMTP is configured, force a renewal failure and check the inbox for the error mail

## 5. IIS bind + post-renewal plugin

Requires IIS installed with at least one HTTPS site.

```powershell
Start-TUACME
# Main menu -> IIS Integration
```

Check:
- [ ] `Show IIS bindings` lists your HTTPS sites with the Posh-ACME match column populated for any cert in PA's store
- [ ] If `Get-PACertificate` is broken (e.g. no account), you now see a warning, not silent skip
- [ ] `Bind certificate to IIS` flow: pick a cert, pick a site, confirm — binding updates and gets registered as the new thumbprint
- [ ] The IIS menu has exactly two actions plus Back (no "Register post-renewal plugin" — that's automatic via the renewal script)

Test the standalone rebind script with a fake old/new thumbprint pair (verifies the rebind logic the renewal script will call):

```powershell
# Pick any two thumbprints from your cert store
$old = (Get-ChildItem Cert:\LocalMachine\My)[0].Thumbprint
$new = (Get-ChildItem Cert:\LocalMachine\My)[1].Thumbprint
powershell.exe -File "$env:ProgramFiles\WindowsPowerShell\Modules\TU-ACME\Scripts\Posh-ACME-IIS-Plugin.ps1" `
    -OldThumbprint $old -Thumbprint $new
Get-EventLog -LogName Application -Source TU-ACME -Newest 3
```

Check:
- [ ] EventId 1002 logged if a binding was updated
- [ ] EventId 1002 logged with `No bindings matched` if no match
- [ ] Per-binding failure does NOT abort remaining bindings (test by deliberately breaking one)

## 6. Scheduled Task setup + overwrite prompt

```powershell
Start-TUACME
# Main menu -> Automation -> Setup Scheduled Task
# Run time: 03:00 (default)
# Account: SYSTEM
```

Check:
- [ ] First run: task `Posh-ACME-AutoRenewal` registered
- [ ] `Get-ScheduledTask -TaskName Posh-ACME-AutoRenewal` shows the task
- [ ] Second run: prompt `Task already exists. Overwrite? (y/N)`:
  - [ ] Blank Enter → returns to menu, task unchanged
  - [ ] Typing `Y` → task re-registered

## 7. SMTP config + test mail (optional but recommended)

```powershell
Start-TUACME
# Main menu -> Automation -> Configure SMTP
```

Check:
- [ ] Walk through prompts; credentials saved to `$env:ProgramData\TU-ACME\smtp-credentials.xml`
- [ ] `(Get-Item $env:ProgramData\TU-ACME\smtp-credentials.xml).Length -gt 0`
- [ ] Send test email → arrives in your inbox
- [ ] Credentials file is DPAPI-encrypted (open in notepad: should NOT be plain text)

## 8. Log viewer

```powershell
Start-TUACME
# Main menu -> Troubleshooting -> View event log
```

Check:
- [ ] Loads TU-ACME entries from the Application log
- [ ] PgUp / PgDn scrolls
- [ ] Esc exits
- [ ] Export log to file: at the `Overwrite? (y/N)` prompt for an existing path, blank Enter cancels (does NOT overwrite)

## Sign-off

- [ ] Section 1 (alignment) - PASS
- [ ] Section 2 (cert order) - PASS
- [ ] Section 3 (dashboard) - PASS
- [ ] Section 4 (renewal script) - PASS
- [ ] Section 5 (IIS) - PASS
- [ ] Section 6 (scheduled task) - PASS
- [ ] Section 7 (SMTP) - PASS or N/A
- [ ] Section 8 (log viewer) - PASS

After all sections pass, switch back to LE production:

```powershell
Set-PAServer LE_PROD
```

Bump version in `TU-ACME.psd1` and tag.
