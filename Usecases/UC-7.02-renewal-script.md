# UC-7.02: Renewal Script (Background Job)

## Narrative

As an **automated system**, I want to **run a renewal script hourly (via Scheduled Task)**, so that **certificates are renewed automatically without user interaction**.

## Acceptance Criteria

- [x] Renewal script is standalone (e.g., `TU-ACME/Scripts/Invoke-Renewal.ps1`)
- [x] Script imports TU-ACME module
- [x] Script calls `Use-TUACMEProdAccount` before any Posh-ACME operation
- [x] Script iterates through all certificates and checks expiry
- [x] Certificates within 30 days of expiry are renewed
- [x] Renewed certificates are imported to LocalMachine\My automatically
- [x] Script logs to Event Log (ID 1001 per renewed cert, ID 3001 on fatal error)
- [x] Script handles errors gracefully (logs, continues to next cert)
- [ ] Script completes in <5 minutes (typical run)
- [x] Script outputs no console output (suitable for scheduled task)

## Implementation Notes

- Script path: `TU-ACME/Scripts/Invoke-Renewal.ps1`
- Renewal threshold: 30 days (configurable?)
- Import destination: `LocalMachine\My`
- Error handling: log and continue (not fatal per cert)
- Scheduled Task runs as SYSTEM

## Test Coverage

**Unit:** Mock Posh-ACME and cert operations; verify renewal logic.

**Integration:** Run script against a test Posh-ACME store; verify renewals and imports.

**Scripts:** Full end-to-end test with fake cert objects and renewal scenarios.
