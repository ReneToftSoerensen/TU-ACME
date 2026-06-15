# UC-6.03: Force-Renew with New Key

## Narrative

As an **operator**, I want to **force-renew a certificate with a new private key**, so that **I can address key rotation requirements or security concerns**.

## Acceptance Criteria

- [x] Force-renew operation calls `Use-TUACMEProdAccount` to ensure prod context
- [x] User selects a certificate from the list
- [x] `-NewKey` flag triggers key regeneration in Posh-ACME
- [x] A new private key is generated
- [x] A new certificate is ordered with the new key
- [x] New certificate is placed in the prod store
- [x] Event Log entry ID 1005 is written with domain and new thumbprint
- [x] New certificate is imported to LocalMachine\My
- [x] Old certificate remains in the store (for reference)

## Implementation Notes

- Function: Called via menu → private force-renew helper
- Posh-ACME's `-NewKey` parameter triggers this behavior
- User confirmation recommended (not required, but good practice)

## Test Coverage

**Unit:** Mock Posh-ACME operations with `-NewKey` flag; verify new key is used.

**Integration:** Force-renew an existing cert; verify new cert and key in store.

**Scripts:** N/A
