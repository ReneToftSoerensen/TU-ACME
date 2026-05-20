# UC-3.3: Store API credentials encrypted on disk

**Category:** DNS plugins and credentials  
**Priority:** High

## Goal
Store the passwords in such a way that only the system (and the background task) can read them.

## Actors
- System administrator (Admin)

## Preconditions
- API credentials have been collected as a `SecureString` (UC-3.2).

## Main flow
1. The sensitive parameters that were entered (from UC-3.2) are already converted to a `SecureString` in PowerShell.
2. The app stores them encrypted on disk via one of the following methods:
   - **Posh-ACME's own system:** Credentials are stored as a hashtable and handed directly to `New-PACertificate` via `-PluginArgs`, where Posh-ACME handles encryption using DPAPI.
   - **Supplementary storage:** A configuration file is saved with `Export-Clixml`, which uses DPAPI-based encryption (only accessible to the user/machine that saved them).
3. A confirmation message is displayed: `Credentials stored encrypted.`

## Postconditions
- Credentials are stored encrypted and can only be decrypted by the same user/machine.
- The background task (UC-5.4) can load the credentials without user interaction.

## Alternative flows
- **2a:** DPAPI is not available (e.g. Linux/non-Windows) -> error message and warning about missing encryption.

## Technical notes
- DPAPI encryption: `$SecureString | ConvertFrom-SecureString` (machine-bound)
- `Export-Clixml` with `SecureString` uses DPAPI automatically.
- Encrypted files should be stored in: `$env:LOCALAPPDATA\Posh-ACME\PluginData\`
