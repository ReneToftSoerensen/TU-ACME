---
name: improve-renewal-notification
description: Use when the user asks to add or change fields in the renewal email (success or failure). Keeps mail body, SMTP test mail, and event log payloads in sync.
---

Renewal mail is composed in `TU-ACME/Scripts/Invoke-RenewalBackground.ps1`. The SMTP transport and the test-mail body live in `TU-ACME/Private/Automation/Invoke-SMTPConfig.ps1`.

## Required body fields

Every failure mail must include:

- **FQDN** of the host (`[System.Net.Dns]::GetHostByName($env:COMPUTERNAME).HostName`, not `$env:COMPUTERNAME` on its own — single-label hostnames are useless across sites).
- **Account context:** `$env:USERNAME` and `$env:USERDOMAIN`. Background renewal runs as `SYSTEM`; the field is still useful so the operator knows whether it was interactive or scheduled.
- **Active ACME directory URL** (read via `Get-PAServer`, not from `config.json` — the running session is the source of truth).
- **Certificate identifier:** primary `MainDomain` and the order's `Name`.
- **Full stack trace** on exception: `$_.ScriptStackTrace` and `$_.Exception.ToString()`. Do not truncate.

Success mail includes the first four, no stack trace.

## Cross-references to keep in sync

- **Event log:** every mail send corresponds to an event log entry. Failure mail → event 3001. Success mail → event 1001. Test mail → event 1007. Register new mail kinds via the `register-event-id` skill (the event-ID registry lives in `docs/operations-and-references.md`).
- **Test mail body** in `Invoke-SMTPConfig.ps1` is a versioned literal. If the body is reshaped, bump the module version via the `bump-version` skill — the version table lists this file.
- **Dry-run path** must use the staging ACME directory in the mail body, not prod. Verify the bootstrap helpers are in the active stack before reading `Get-PAServer`.

## Do not

- Log credential bodies (SMTP password, DNS plugin secrets). Log presence and result only.
- Hardcode the directory URL — always derive from `Get-PAServer`, otherwise dry-run lies in the mail.
- Send mail without a `try/catch` around `Send-MailMessage`; a broken SMTP server must not kill the renewal pass.
