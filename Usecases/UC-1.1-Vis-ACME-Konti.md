# UC-1.1: Show list of existing ACME accounts

**Category:** Account management  
**Priority:** High

## Goal
Give the administrator an overview of configured Let's Encrypt / ACME accounts.

## Actors
- System administrator (Admin)
- Monitor/Technician (ReadOnly)

## Preconditions
- Posh-ACME is installed and configured with at least one account.

## Main flow
1. The user selects "Account management" in the main menu.
2. The TUI loads accounts from the Posh-ACME profile path via `Get-PAAccount`.
3. A list of registered email addresses and their associated ACME servers (Production/Staging) is displayed on the screen.

## Postconditions
- The user has an overview of all registered ACME accounts.

## Alternative flows
- **2a:** No accounts found -> The TUI shows the message: `No ACME accounts found. Create a new account (UC-1.2).`

## Technical notes
- PowerShell command: `Get-PAAccount -List`
- Profile path typically: `$env:LOCALAPPDATA\Posh-ACME`
