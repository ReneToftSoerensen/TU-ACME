# UC-6.01: Renew Certificate

## Narrative

As an **operator**, I want to **renew an existing certificate manually**, so that **I can extend its validity before the automatic renewal is triggered**.

## Acceptance Criteria

- [ ] Renew operation calls `Use-TUACMEProdAccount` to ensure prod context
- [ ] User selects a certificate from the list
- [ ] `Submit-Renewal` is invoked for the selected cert (via Posh-ACME)
- [ ] New certificate is issued and placed in the prod store
- [ ] Old certificate remains in the store (Posh-ACME behavior)
- [ ] Event Log entry ID 1001 is written with domain and renewal details
- [ ] Certificate is imported to LocalMachine\My after renewal
- [ ] Return value includes old and new thumbprints

## Implementation Notes

- Function: Called via menu → private renew helper → `Submit-Renewal`
- Certificate selection happens via menu or direct parameter
- Import to LocalMachine\My happens after successful renewal

## Test Coverage

**Unit:** Mock `Use-TUACMEProdAccount`, `Submit-Renewal`, cert import; verify flow.

**Integration:** Manually renew an existing cert in the store; verify new cert appears.

**Scripts:** Renewal script exercises this flow hourly/on-schedule.
