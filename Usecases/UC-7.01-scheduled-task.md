# UC-7.01: Scheduled Task Installation

## Narrative

As an **administrator**, I want to **install a Windows Scheduled Task for background renewal**, so that **certificates are automatically renewed without operator intervention**.

## Acceptance Criteria

- [ ] Install option is available in the main TUI menu (Admin only)
- [ ] User confirms task creation (safety check)
- [ ] A Windows Scheduled Task is created to run the renewal script
- [ ] Task is named `TU-ACME-Renewal` (or similar)
- [ ] Task runs the renewal script (e.g., `renewal.ps1`) with appropriate parameters
- [ ] Task is configured to run every 1 hour (or per policy)
- [ ] Task runs as SYSTEM (with SYSTEM privileges)
- [ ] Task is set to run on system startup and at scheduled interval
- [ ] Event Log entry ID 1008 is written on successful installation
- [ ] Clear confirmation message is displayed with task name and schedule

## Implementation Notes

- Function: `Invoke-SMTPConfig` or similar (stored in `Private/Automation/`)
- Task creation uses `Register-ScheduledTask` (Windows-only)
- Task runs renewal script with appropriate error handling

## Test Coverage

**Unit:** Mock `Register-ScheduledTask`; verify parameters and schedule.

**Integration:** Create a task; verify it appears in Task Scheduler.

**Scripts:** N/A
