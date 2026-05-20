# UC-0.1: Administrator privilege check on startup

**Category:** System  
**Priority:** High

## Goal
Ensure that administrative functions (such as IIS changes and Scheduled Tasks) are only available when the TUI is running with elevated privileges.

## Actors
- System administrator (Admin)
- Monitor/Technician (ReadOnly)

## Preconditions
- The TUI application is installed and ready to start.

## Main flow
1. The TUI starts up.
2. The system checks whether the current PowerShell process is running as Administrator.
3. If **not** an administrator:
   - The system displays a **red warning bar** at the top of the TUI:  
     `NOT RUNNING AS ADMINISTRATOR - Administrative functions are disabled`
   - Menus belonging to UC-5 (Automation) and UC-8 (IIS Integration) are disabled or hidden.
4. If administrator: the TUI starts with full access to all menus and functions.

## Postconditions
- The TUI has started with the correct access level for the current user.

## Alternative flows
- **3a:** The user restarts the TUI as administrator -> Full access is granted.

## Technical notes
- Use `[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)` to check privileges.
