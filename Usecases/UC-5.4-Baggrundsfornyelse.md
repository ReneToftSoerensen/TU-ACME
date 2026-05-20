# UC-5.4: Run silent background renewal with error capture

**Category:** Automation  
**Priority:** High

## Goal
The script run by Task Scheduler must renew certificates and send an email to the administrator if it fails.

## Actors
- Windows Task Scheduler (automatic trigger)
- System administrator (Admin) - receives email on failure

## Preconditions
- The Scheduled Task has been created (UC-5.1).
- SMTP settings are configured (UC-5.2).
- At least one certificate is managed by Posh-ACME.

## Main flow
1. The Scheduled Task triggers the headless script `Invoke-RenewalBackground.ps1` at the configured time.
2. The script loads the Posh-ACME module.
3. The script calls `Submit-Renewal` inside a `try/catch` block.
4. Posh-ACME renews all certificates that expire within 30 days.
5. If the renewal succeeds: the script logs success in the Windows Event Log and exits silently.

## Error handling (alternative flow on failure)
6. If an exception is thrown, or Posh-ACME reports a failure status:
   a. The script loads the encrypted SMTP settings (UC-5.2/UC-3.3).
   b. The script generates an error report:
      ```
      Timestamp:    2026-05-18 03:01:55
      Domain:       example.com
      Error:        [Posh-ACME error message here]
      Log file:     C:\...\posh-acme.log
      ```
   c. The script sends the error email to the configured recipient.
   d. The script logs an error in the Windows Event Log (source: `TU-ACME`).
7. The post-renewal script for IIS update (UC-8.4) is triggered automatically by Posh-ACME.

## Postconditions
- Certificates have been renewed (on success).
- Administrator has been notified by email (on failure).
- The event is logged in the Windows Event Log.

## Technical notes
- PowerShell command: `Submit-Renewal`
- Windows Event Log: `New-EventLog -Source "TU-ACME" -LogName Application`
- The script is run with `-NonInteractive -WindowStyle Hidden` for headless operation.
