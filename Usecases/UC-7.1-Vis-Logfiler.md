# UC-7.1: Browse the most recent log files directly in the TUI (Pager)

**Category:** Troubleshooting  
**Priority:** Medium

## Goal
Read Posh-ACME's log files without having to leave the TUI application or open Notepad.

## Actors
- System administrator (Admin)
- Monitor/Technician (ReadOnly)

## Preconditions
- Posh-ACME is installed and has log files.

## Main flow
1. The user selects "View Logs" in the menu.
2. The TUI loads the most recent log file from the Posh-ACME log folder.
3. The contents of the log file are displayed in a scrollable text view in the terminal.
4. Navigation in the log:
   - **Up / Down** Arrow keys scroll one line at a time
   - **PageUp / PageDown** Scroll one page at a time
   - **Home / End** Jump to the top / bottom
5. The user presses **ESC** or **Q** to return to the menu.

## Postconditions
- The user has been able to read the log file and has returned to the menu.

## Alternative flows
- **2a:** No log file found -> Message: `No log file found in the Posh-ACME log folder.`
- **2b:** Multiple log files -> The TUI shows a list of the most recent log files and the user picks one.

## Technical notes
- Log file path: typically `$env:LOCALAPPDATA\Posh-ACME\*.log` or Posh-ACME's configuration folder.
- The pager is implemented with `[Console]::SetCursorPosition` and manual scroll logic.
- From the log view the user can start UC-7.2 (export).
