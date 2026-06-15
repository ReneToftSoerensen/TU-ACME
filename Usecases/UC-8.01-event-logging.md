# UC-8.01: Event Log Integration

## Narrative

As an **operator**, I want to **see all TU-ACME operations logged to Windows Event Log**, so that **I can audit certificate activities and diagnose issues**.

## Acceptance Criteria

- [x] Custom event log source `TU-ACME` is registered during first-run
- [x] ID 1000: Session start (Information)
- [x] ID 1001: Renewal completed (Information, per cert)
- [ ] ID 1002: IIS binding refreshed (Information)
- [x] ID 1003: Certificate ordered (Information)
- [ ] ID 1004: Certificate revoked (Information)
- [ ] ID 1005: Force-renew with new key (Information)
- [x] ID 1006: Dry-run certificate issued (Information)
- [ ] ID 1007: SMTP test mail sent (Information)
- [x] ID 1008: Scheduled renewal task installed (Information)
- [ ] ID 1009: Certificate exported to PFX (Information)
- [x] ID 1010: Module initialization / first-run completed (Information)
- [x] ID 1011: Certificate imported to LocalMachine\My (Information)
- [ ] ID 2001: IIS rebind failed (Warning, operation continues)
- [ ] ID 2xxx: Other recoverable issues (Warning)
- [x] ID 3001: Background renewal job aborted (Error)
- [x] ID 3002: Certificate order failed (Error)
- [x] ID 3003: Certificate renewal failed (Error)
- [x] ID 3xxx: Unrecoverable failures (Error)
- [x] Each log entry includes sufficient context (domain, thumbprint, error details)

## Implementation Notes

- Event source registration happens in `Initialize-TUACMEEnvironment`
- Logging happens via helper function (e.g., `Write-TUACMEEventLog`)
- Source name must match registry entry for permissions

## Test Coverage

**Unit:** Mock event log functions; verify event parameters.

**Integration:** Perform operations; verify events appear in Event Log.

**Scripts:** Renewal script logs appropriately.
