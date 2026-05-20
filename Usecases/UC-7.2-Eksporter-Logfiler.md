# UC-7.2: Export log files to an external file

**Category:** Troubleshooting  
**Priority:** Low

## Goal
Easily collect log files together to send to support or for further troubleshooting.

## Actors
- System administrator (Admin)
- Monitor/Technician (ReadOnly)

## Preconditions
- Log view is active (UC-7.1).
- The desired log file has been loaded.

## Main flow
1. While the log view is active (UC-7.1), the user presses **E** for export.
2. The TUI suggests a default destination path:  
   `Save log file as: C:\Users\<user>\Desktop\posh-acme-log-2026-05-18.txt`
3. The user can accept the default with Enter or type a different path.
4. The TUI saves a copy of the current log file to the specified path.
5. Success message is shown:  
   `[OK] Log file saved: C:\Users\admin\Desktop\posh-acme-log-2026-05-18.txt`

## Postconditions
- A copy of the log file is saved at the specified path, ready to be sent to support.

## Alternative flows
- **3a:** Path is invalid or write permissions are missing -> Error message.
- **4a:** File already exists -> The user is asked about overwriting.

## Technical notes
- The file name automatically includes the date for traceability: `posh-acme-log-YYYY-MM-DD.txt`
- Use `Copy-Item` or `Get-Content | Set-Content` for copying.
