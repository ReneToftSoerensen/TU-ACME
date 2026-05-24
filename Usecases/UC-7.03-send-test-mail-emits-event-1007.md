# UC-7.03 — Send-Test emits Event 1007 on success

**Behavior:** Selecting "Send test mail" from the SMTP menu invokes `Send-TUACMEMail` exactly once with `Subject 'TU-ACME test mail'`; on a successful send, `Invoke-SMTPSendTest` writes a `1007 Information` entry to the TU-ACME event log.

**Given** an SMTP-configured TU-ACME where `Send-TUACMEMail` returns `$true`
**When** the operator selects option 2 (Send test mail) from `Invoke-SMTPConfig`
**Then** `Send-TUACMEMail` is called once with `Subject 'TU-ACME test mail'` and `Write-EventLogEntry` is called once with `EventId 1007`

**Implementation:** `TU-ACME/Private/Automation/Invoke-SMTPConfig.ps1`
**Test:** `tests/Unit/Automation/UC-7.03.Tests.ps1`
