# UC-6.02: Revoke Certificate

## Narrative

As an **operator**, I want to **revoke a certificate that is no longer needed or has been compromised**, so that **the certificate is marked as invalid with the CA**.

## Acceptance Criteria

- [x] Revoke operation calls `Use-TUACMEProdAccount` to ensure prod context
- [x] User selects a certificate from the list
- [x] Operator is prompted to confirm revocation (safety check)
- [x] `Revoke-PACertificate` is invoked (via Posh-ACME)
- [x] Certificate is marked as revoked in the Posh-ACME store
- [x] Event Log entry ID 1004 is written with domain and thumbprint
- [x] IIS bindings still referencing the revoked certificate are reported to the operator for manual rebind (if applicable)
- [x] Clear confirmation message is displayed

## Implementation Notes

- Function: Called via menu → private revoke helper → `Revoke-PACertificate`
- Confirmation prompt prevents accidental revocation
- Bindings still serving the revoked cert are reported for manual rebind, not auto-unbound (an HTTPS binding cannot be left without a certificate)

## Test Coverage

**Unit:** Mock `Revoke-PACertificate` and confirmation logic; verify safety flow.

**Integration:** Revoke a cert in the store; verify revoked status in Posh-ACME.

**Scripts:** N/A
