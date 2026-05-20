# UC-5.2: Configure and save SMTP settings for email

**Category:** Automation  
**Priority:** High

## Goal
Configure the SMTP details to be used for sending warning emails if the automatic renewal fails.

## Actors
- System administrator (Admin)

## Preconditions
- TUI is running with administrator privileges (UC-0.1).

## Main flow
1. The user selects "Configure failure notification".
2. The TUI prompts for the following parameters:
   - **SMTP server** (e.g. `smtp.office365.com`)
   - **Port** (default: `587`)
   - **Sender email** (e.g. `noreply@example.com`)
   - **Recipient email** (administrator)
   - **Requires SSL/TLS?** [Y/N]
   - **Requires login?** [Y/N]
3. If login is required: prompted for username and password (the password is masked, UC-3.2).
4. All settings are saved encrypted in a central JSON configuration file (the password is stored as an encrypted `SecureString`, UC-3.3).
5. Message shown: `SMTP configuration saved.`

## Postconditions
- SMTP settings are saved encrypted and ready for use in the background script (UC-5.4).

## Alternative flows
- **3a:** Login not required -> Skip the username/password prompt.

## Technical notes
- Configuration file is saved as: `$env:ProgramData\TU-ACME\smtp-config.xml` (encrypted with Export-Clixml).
- `Send-MailMessage` or .NET `System.Net.Mail.SmtpClient` is used for sending.
