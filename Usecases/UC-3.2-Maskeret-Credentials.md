# UC-3.2: Enter and mask API credentials in prompt

**Category:** DNS plugins and credentials  
**Priority:** High

## Goal
Ensure that passwords and API keys cannot be read on the screen while they are being typed.

## Actors
- System administrator (Admin)

## Preconditions
- A DNS plugin has been selected (UC-3.1).
- The TUI knows the required parameters for the selected plugin.

## Main flow
1. The TUI displays a list of the required parameters for the selected plugin, e.g. for Cloudflare:
   ```
   Cloudflare configuration:
   API Token (secret): _
   ```
2. For each parameter marked as secret:
   - When the user types, only `*` is shown for each character (or the input is hidden entirely).
   - Backspace works correctly and removes the most recently hidden character.
3. For non-secret parameters (e.g. zone ID), the input is shown normally.
4. The user confirms all parameters.

## Postconditions
- API credentials have been collected as a `SecureString` in memory.
- Credentials are passed on to UC-3.3 for encrypted storage.

## Alternative flows
- **2a:** The user presses ESC -> aborts without saving.

## Technical notes
- Use `Read-Host -AsSecureString` for masked input in PowerShell.
- Plugin parameters and their type (secret/public) are documented in Posh-ACME's plugin help files.
