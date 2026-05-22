# Posh-ACME returns empty `MainDomain` / `Issuer` / `SANs` for internal-CA certs

**Symptom**: A cert that issued successfully and is on disk shows `Domain (CN):` empty, `SAN domains:` empty, `Issuer:` empty in the dashboard detail view — yet `Thumbprint`, `NotAfter`, `CertFile`, `KeyFile` are populated.
**Discovered**: 2026-05-21 against an internal ACME CA at `https://acme` issuing certs for bare hostnames (`df-bpxt4s2-ws`)
**Affects**: Posh-ACME 4.x against non-Let's-Encrypt ACME implementations whose order.json schema omits fields LE always populates.

## What broke
`Get-PACertificate -List` reads `MainDomain`, `Issuer`, `SANs`, and `Plugin` from order.json. Some internal CAs return enough metadata for the cert to be issued and saved on disk, but the order.json that Posh-ACME persists ends up missing those four fields. The X.509 cert file itself has CN, Issuer DN, and Subject Alternative Names — Posh-ACME just doesn't extract them.

## Root cause
Posh-ACME trusts order.json as the metadata source of truth and never falls back to parsing the X.509 file. Internal CAs that don't echo `MainDomain` in the ACME directory document leave that field blank.

## Fix
`_Enrich-TUACMECertFromFile` in `TU-ACME/Private/Helpers/Get-TUACMEAllCertificates.ps1` opens the cert file with `[X509Certificate2]` and backfills any missing field:

- `MainDomain` ← Subject `CN=...`, falling back to the cert folder name (Posh-ACME names cert folders after MainDomain).
- `Issuer` ← X.509 Issuer DN.
- `SANs` ← `SubjectAlternativeName` extension (OID `2.5.29.17`) via `Format($false)` then strip the `DNS Name=` / `IP Address=` prefix per entry.

Skip the open if all three are already populated, so we don't pay X.509 parse cost for normal LE certs.

## See also
- `posh-acme-empty-cert-objects.md`
- `posh-acme-folder-layout.md`
