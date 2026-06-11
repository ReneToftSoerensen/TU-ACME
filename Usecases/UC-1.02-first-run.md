# UC-1.02: First-Run Wizard

## Narrative

As an **administrator**, I want to **run the first-run wizard when `config.json` is missing**, so that **TU-ACME initializes with a production and staging account and is ready for certificate operations**.

## Acceptance Criteria

- [x] First-run wizard triggers automatically on `Start-TUACME` if `%ProgramData%\TU-ACME\config.json` is absent; module import warns instead of prompting so import never blocks non-interactive sessions (AC-A.1)
- [x] Wizard prompts for contact email
- [x] Wizard prompts for production ACME directory URL
- [x] Wizard prompts for staging ACME directory URL
- [x] Wizard creates exactly two accounts (prod + staging) in the Posh-ACME store
- [x] Wizard persists config to `%ProgramData%\TU-ACME\config.json` with plaintext URLs, account IDs, and email
- [x] Event Log entry ID 1010 is written on completion
- [x] On reimport, the wizard does not trigger and config is loaded

## Implementation Notes

- Function: `Initialize-TUACMEEnvironment` (called on module import)
- Config path: `%ProgramData%\TU-ACME\config.json`
- Uses `New-PAAccount` and `Set-PAAccount` from Posh-ACME
- Posh-ACME store path: `%ProgramData%\Posh-ACME\` (via `$env:POSHACME_HOME`)
- Event Log source must be registered in advance

## Test Coverage

**Unit:** Mock Posh-ACME and file I/O; verify config structure and account creation.

**Integration:** Run against a real Posh-ACME store; verify two accounts exist and config persists.

**Scripts:** N/A
