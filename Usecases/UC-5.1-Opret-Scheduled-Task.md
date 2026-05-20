# UC-5.1: Create Windows Scheduled Task for nightly run

**Category:** Automation  
**Priority:** High

## Goal
Create the Windows Scheduled Task that will run the automatic renewal in the background.

## Actors
- System administrator (Admin)

## Preconditions
- TUI is running with administrator privileges (UC-0.1).
- Posh-ACME is installed and at least one certificate is being managed.

## Main flow
1. The user selects "Automation" -> "Create Scheduled Task".
2. The TUI prompts for configuration parameters:
   - **Run time** (default: `03:00`)
   - **User account** to run the task: `SYSTEM` / `Specific user`
3. The TUI shows a summary and asks for confirmation.
4. The system generates a Scheduled Task with:
   - Name: `Posh-ACME-AutoRenewal`
   - Trigger: Daily at the selected time
   - Action: `powershell.exe -NonInteractive -File "C:\...\Invoke-RenewalBackground.ps1"`
   - Run account: The selected account
5. The task is created via `Register-ScheduledTask` and confirmed to the user.

## Postconditions
- The Windows Scheduled Task is created and active.
- Automatic renewal will run night after night.

## Alternative flows
- **2a:** The user selects "Specific user" -> Prompted for username and password.
- **5a:** Task already exists -> The TUI asks whether it should be overwritten.
- **5b:** Error during creation -> A precise error message is shown.

## Technical notes
- PowerShell command: `Register-ScheduledTask -TaskName "Posh-ACME-AutoRenewal" -Action $action -Trigger $trigger -RunLevel Highest`
- The task must run with "Run whether user is logged on or not" for headless operation.
