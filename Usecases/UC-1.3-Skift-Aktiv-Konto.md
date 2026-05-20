# UC-1.3: Switch active ACME account

**Category:** Account management  
**Priority:** High

## Goal
Select which of the registered accounts should be the active one in the current Posh-ACME configuration.

## Actors
- System administrator (Admin)

## Preconditions
- At least two ACME accounts are registered (UC-1.1).

## Main flow
1. The user navigates to the list of existing accounts (UC-1.1).
2. The user highlights the desired account using the arrow keys.
3. The user selects "Set as active" (Enter or a dedicated key).
4. The application calls `Set-PAAccount` with the ID of the selected account.
5. The status bar at the bottom of the TUI is updated with the new active account.

## Postconditions
- The selected account is now active and will be used for all subsequent certificate operations.

## Alternative flows
- **4a:** Error when switching account -> An error message is shown, the active account remains unchanged.

## Technical notes
- PowerShell command: `Set-PAAccount -ID "<account-id>"`
