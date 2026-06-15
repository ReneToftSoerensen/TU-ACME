# UC-5.02: Order Certificate (Dry-Run)

## Narrative

As an **operator**, I want to **order a certificate against staging for testing**, so that **I can validate the workflow without affecting production**.

## Acceptance Criteria

- [x] Order operation accepts `-DryRun` flag
- [x] With `-DryRun`, operation calls `Use-TUACMEStagingAccount` at start
- [x] Certificate is issued against staging account
- [x] Certificate appears in staging store only, not prod
- [x] Operation calls `Use-TUACMEProdAccount` in finally block to restore prod context
- [x] Prod context is restored even if the order fails
- [x] Event Log entry ID 1006 is written on success
- [x] Dry-run certificate is **not** imported to LocalMachine\My

## Implementation Notes

- Same function as UC-5.01, but with `-DryRun` flag handling
- Try/finally ensures prod restoration
- Certificate import step is skipped for dry-run

## Test Coverage

**Unit:** Mock dry-run flow and account switching; verify finally block executes.

**Integration:** Run dry-run order; verify cert in staging, prod untouched, prod context restored.

**Scripts:** N/A
