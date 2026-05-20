# UC-8.1: Scan local IIS sites and HTTPS bindings

**Category:** IIS Integration  
**Priority:** High

## Goal
Identify which websites on the machine are currently running with HTTPS, and which certificates they use.

## Actors
- System administrator (Admin)

## Preconditions
- TUI is running with administrator privileges (UC-0.1).
- IIS (Internet Information Services) is installed on the machine.
- The PowerShell module `WebAdministration` is available.

## Main flow
1. The user selects "IIS integration" -> "Show bindings".
2. The system imports the `WebAdministration` module.
3. The system scans all IIS websites for HTTPS bindings (port 443 and other SSL ports).
4. A table is shown with:
   ```
   Site name         Binding              Thumbprint (current)      Match in Posh-ACME?
   ---------------------------------------------------------------------------------
   Example-site      https *:443:         A1B2C3D4E5F6...           Yes (example.com)
   Test-site         https *:8443:test    AABBCC112233...           No
   ```

## Postconditions
- The administrator has an overview of all IIS HTTPS bindings and their certificate status.

## Alternative flows
- **2a:** `WebAdministration` module not found -> Error message: `IIS is not installed or the WebAdministration module is missing.`
- **3a:** No HTTPS bindings found -> Message: `No HTTPS bindings found in IIS.`

## Technical notes
- PowerShell commands:
  ```powershell
  Import-Module WebAdministration
  Get-WebBinding -Protocol "https" | Select-Object bindingInformation, certificateHash
  ```
- Matching with Posh-ACME: compare `certificateHash` (thumbprint) with `(Get-PACertificate -List).Thumbprint`
