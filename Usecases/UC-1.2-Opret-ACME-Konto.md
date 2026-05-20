# UC-1.2: Create new ACME account

**Category:** Account management  
**Priority:** High

## Goal
Register a new account with an ACME provider (Let's Encrypt, ZeroSSL, or custom).

## Actors
- System administrator (Admin)

## Preconditions
- The user is running the TUI as Administrator.
- Internet access is available to the ACME provider's endpoint.

## Main flow
1. The user selects "Create new account" in the Account management menu.
2. The TUI prompts for an email address (contact address for the ACME provider).
3. The TUI displays a list of known ACME servers:
   - Let's Encrypt (Production)
   - Let's Encrypt (Staging)
   - ZeroSSL
   - Custom (user-defined URL)
4. The user selects a server.
5. The TUI shows the Terms of Service and prompts: `Do you accept the terms? [Y/N]`.
6. The user confirms with `Y`.
7. The application calls `New-PACAccount` and creates the account.
8. A success message is shown with the new account's ID and email address.

## Postconditions
- A new ACME account is registered and set as the active account.

## Alternative flows
- **4a:** Custom server selected -> The user is prompted for the server URL.
- **6a:** The user answers `N` -> Cancelled, no account is created.
- **7a:** Network error -> An error message is shown with the exact error text.

## Technical notes
- PowerShell command: `New-PACAccount -AcceptTOS -Contact "mail@example.com"`
- For a custom server: `New-PAServer -DirectoryUrl "https://custom.acme/dir"`
