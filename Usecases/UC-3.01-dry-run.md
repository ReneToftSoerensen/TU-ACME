# UC-3.01: Dry-Run (Staging Test)

## Narrative

As an **operator**, I want to **perform a dry-run certificate order against staging**, so that **I can test the entire workflow (validation, issuance, import) without affecting production**.

## Acceptance Criteria

- [x] `-DryRun` flag on order operation switches to staging account before operation
- [x] Certificate is issued against staging account and appears only in staging store
- [x] Production account context is restored after dry-run (success or failure)
- [x] Any errors during dry-run do not leave the system in staging context
- [x] Event Log entry ID 1006 is written on successful dry-run

## Implementation Notes

- Dry-run is implemented via a `try/finally` block that calls:
  1. `Use-TUACMEStagingAccount` (save previous server)
  2. Perform the operation
  3. Finally: `Use-TUACMEProdAccount` (restore)
- Only certificate order/renewal operations support `-DryRun`
- Dry-run does **not** import the certificate to LocalMachine\My

## Test Coverage

**Unit:** Mock Posh-ACME account switching; verify try/finally flow.

**Integration:** Run a dry-run order against a real Posh-ACME store; confirm cert in staging only, prod restored.

**Scripts:** N/A
