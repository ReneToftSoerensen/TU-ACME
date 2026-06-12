# UC-8.01: Event Log Integration

## Narrative

As an **operator**, I want to **see all TU-ACME operations logged to Windows Event Log**, so that **I can audit certificate activities and diagnose issues**.

## Acceptance Criteria

- [ ] Custom event log source `TU-ACME` is registered during first-run
- [ ] ID 1000: Session start (Information)
- [ ] ID 1001: Renewal completed (Information, per cert)
- [ ] ID 1002: IIS binding refreshed (Information)
- [ ] ID 1003: Certificate ordered (Information)
- [ ] ID 1004: Certificate revoked (Information)
- [ ] ID 1005: Force-renew with new key (Information)
- [ ] ID 1006: Dry-run certificate issued (Information)
- [ ] ID 1007: SMTP test mail sent (Information)
- [ ] ID 1008: Scheduled renewal task installed (Information)
- [ ] ID 1009: Certificate exported to PFX (Information)
- [ ] ID 1010: Module initialization / first-run completed (Information)
- [ ] ID 1011: Certificate imported to LocalMachine\My (Information)
- [ ] ID 2001: IIS rebind failed (Warning, operation continues)
- [ ] ID 2xxx: Other recoverable issues (Warning)
- [ ] ID 3001: Background renewal job aborted (Error)
- [ ] ID 3002: Certificate order failed (Error)
- [ ] ID 3003: Certificate renewal failed (Error)
- [ ] ID 3xxx: Unrecoverable failures (Error)
- [ ] Each log entry includes sufficient context (domain, thumbprint, error details)

## Implementation Notes

- Event source registration happens in `Initialize-TUACMEEnvironment`
- Logging happens via helper function (e.g., `Write-TUACMEEventLog`)
- Source name must match registry entry for permissions

## Test Coverage

**Unit:** Mock event log functions; verify event parameters.

**Integration:** Perform operations; verify events appear in Event Log.

**Scripts:** Renewal script logs appropriately.
