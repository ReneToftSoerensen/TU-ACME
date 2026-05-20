# UC-8.3: Register Post-Renewal Plugin (IIS Update) in Posh-ACME

**Category:** IIS Integration  
**Priority:** High

## Goal
Configure Posh-ACME to automatically run the IIS update script every time a certificate is renewed in the background.

## Actors
- System administrator (Admin)

## Preconditions
- TUI is running with administrator privileges (UC-0.1).
- Posh-ACME is installed.
- The post-renewal script `Posh-ACME-IIS-Plugin.ps1` is included in the TUI installation.

## Main flow
1. The user selects "IIS integration" -> "Set up auto-update of bindings".
2. The TUI identifies the full path to the bundled plugin script:  
   `C:\Program Files\TU-ACME\Scripts\Posh-ACME-IIS-Plugin.ps1`
3. The TUI shows the path and asks for confirmation:  
   `Register IIS plugin: [path]? [Y/N]`
4. The user confirms with **Y**.
5. The app calls:
   ```powershell
   Set-PAConfig -PostScript "C:\...\Posh-ACME-IIS-Plugin.ps1"
   ```
6. Success message: `IIS auto-update enabled. Post-renewal plugin is registered.`

## Postconditions
- Posh-ACME is configured to call the IIS update script after each successful renewal.
- Automatic IIS update (UC-8.4) is now active.

## Alternative flows
- **2a:** Plugin script not found -> Error message with guidance for manually placing the script.
- **4a:** The user answers N -> Aborted with no changes.

## Technical notes
- PowerShell command: `Set-PAConfig -PostScript "<path>"`
- The script receives certificate details as parameters from Posh-ACME on renewal.
- Any existing post-script configuration is shown before it is overwritten.
