# UC-8.4: Automatic IIS update via Post-Renewal script

**Category:** IIS Integration  
**Priority:** High

## Goal
The automatic background process that ensures IIS bindings always have the latest certificate, without the administrator having to lift a finger.

## Actors
- Posh-ACME (automatic trigger after renewal)
- Windows Task Scheduler (indirectly via UC-5.4)

## Preconditions
- The Scheduled Task is created and runs `Submit-Renewal` (UC-5.1 / UC-5.4).
- The post-renewal plugin is registered in Posh-ACME (UC-8.3).
- The certificate has previously been bound to IIS bindings (UC-8.2).

## Main flow
1. Posh-ACME (run by Task Scheduler, UC-5.4) performs a successful renewal of the certificate.
2. Posh-ACME automatically triggers the registered post-script (`Posh-ACME-IIS-Plugin.ps1`) and passes the following parameters:
   - The **new** certificate (path and thumbprint)
   - The **old** certificate (thumbprint)
3. The post-script automatically imports the new certificate into the Windows Certificate Store (`LocalMachine\My`).
4. The post-script scans all IIS bindings for the old thumbprint.
5. For each binding that matches the old thumbprint:
   - The binding is updated with the new thumbprint.
6. The event is logged in the Windows Event Log:
   ```
   Source:  TU-ACME
   Message: IIS binding for example.com (*:443:) updated.
            Old thumbprint: A1B2C3...
            New thumbprint: D4E5F6...
   ```

## Postconditions
- All IIS bindings are updated with the latest certificate.
- IIS does not need a restart (IIS automatically picks up the new certificate).
- The event is logged in the Windows Event Log.

## Alternative flows
- **4a:** No IIS bindings use the old thumbprint -> The script exits silently with no changes.
- **5a:** Error updating a specific binding -> The error is logged in the Windows Event Log; the remaining bindings are still updated.

## Technical notes
- The post-script receives parameters: `$OldCertThumbprint`, `$NewCertPath`, `$NewCertThumbprint`
- PowerShell commands:
  ```powershell
  Import-Module WebAdministration
  Get-WebBinding -Protocol "https" | Where-Object { $_.certificateHash -eq $OldCertThumbprint }
  ```
- The script runs with the same privileges as the Task Scheduler job (typically SYSTEM).
