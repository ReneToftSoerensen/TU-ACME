# UC-5.3: Test SMTP connection and send a test email from the TUI

**Category:** Automation  
**Priority:** Medium

## Goal
Allow the administrator to immediately confirm that the SMTP settings work correctly.

## Actors
- System administrator (Admin)

## Preconditions
- SMTP settings are configured and saved (UC-5.2).

## Main flow
1. After saving the SMTP settings (UC-5.2), the user selects "Send test email".
2. The TUI shows: `Sending test email to admin@example.com...`
3. The system loads the encrypted SMTP settings.
4. The system attempts to send a test email with the subject:  
   `[TU-ACME] Test email - SMTP configuration is working`
5. If the send succeeds:
   ```
   [OK] Test email sent successfully to admin@example.com
   ```
6. The user can then confirm receipt in their inbox.

## Postconditions
- The SMTP configuration is verified and ready for use.

## Alternative flows
- **4a:** Connection error -> Red error message with the precise .NET/SMTP error text, e.g.:  
  `[ERROR] System.Net.Mail.SmtpException: Unable to connect to the remote server`
- **4b:** Authentication error -> Message about incorrect username/password.

## Technical notes
- The test email contains a timestamp and the TUI version for traceability.
- Uses the same send logic as the background script (UC-5.4).
