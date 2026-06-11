# UC-7.02: Renewal Script (Background Job)

## Narrative

As an **automated system**, I want to **run a renewal script hourly (via Scheduled Task)**, so that **certificates are renewed automatically without user interaction**.

## Acceptance Criteria

- [ ] Renewal script is standalone (e.g., `TU-ACME/Scripts/Invoke-Renewal.ps1`)
- [ ] Script imports TU-ACME module
- [ ] Script calls `Use-TUACMEProdAccount` before any Posh-ACME operation
- [ ] Script iterates through all certificates and checks expiry
- [ ] Certificates within 30 days of expiry are renewed
- [ ] Renewed certificates are imported to LocalMachine\My automatically
- [ ] Script logs to Event Log (ID 1001 per renewed cert, ID 3001 on fatal error)
- [ ] Script handles errors gracefully (logs, continues to next cert)
- [ ] Script completes in <5 minutes (typical run)
- [ ] Script outputs no console output (suitable for scheduled task)

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
