# UC-5.01: Order Certificate (Production)

## Narrative

As an **operator**, I want to **order a new certificate for a domain**, so that **the certificate is issued and ready for import to IIS and LocalMachine\My**.

## Acceptance Criteria

- [x] Order operation calls `Use-TUACMEProdAccount` to ensure prod context
- [x] `New-PACertificate` is invoked with the domain and contact email
- [x] Certificate is placed in the prod Posh-ACME store
- [x] Certificate thumbprint and expiry are readable after ordering
- [x] Event Log entry ID 1003 is written with domain and thumbprint
- [x] Return value includes certificate thumbprint and expiry date
- [x] On error, a clear error message is displayed and logged

## Implementation Notes

- Function: Called via menu → private order helper → `New-PACertificate`
- Contact email comes from config (set during first-run)
- Domain validation is delegated to Posh-ACME
- Certificate import to LocalMachine\My happens separately (not in this UC)
- The order helper now accepts multiple domains (`-Domain` is `[string[]]`: CN
  first, SANs after) while keeping `.Domain` a scalar primary for single-name
  callers. See **UC-5.03** for the FQDN-as-CN + short-hostname-as-SAN flow.

## Test Coverage

**Unit:** Mock `Use-TUACMEProdAccount`, `New-PACertificate`, event logging; verify parameters.

**Integration:** Order against a real staging directory (not prod); verify cert appears in store.

**Scripts:** N/A
