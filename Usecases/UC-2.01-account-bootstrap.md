# UC-2.01: Account Bootstrap (Prod/Staging Selection)

## Narrative

As an **internal function**, I want to **set the active Posh-ACME account and server** before any certificate operation, so that **orders, renewals, and revocations go to the correct environment (prod or staging)**.

## Acceptance Criteria

- [x] `Use-TUACMEProdAccount` sets the active server to the production URL from config
- [x] `Use-TUACMEProdAccount` sets the active account to the production account ID from config
- [x] `Use-TUACMEStagingAccount` sets the active server to the staging URL from config
- [x] `Use-TUACMEStagingAccount` sets the active account to the staging account ID from config
- [x] Both functions return the previously active server URL (to support restoration)
- [x] No other code path in the module calls `Set-PAServer` or `Set-PAAccount` directly

## Implementation Notes

- Functions: `Use-TUACMEProdAccount`, `Use-TUACMEStagingAccount`
- Stored in: `Private/Bootstrap/`
- Config is loaded via `Get-TUACMEConfig`
- The only callers of `Set-PAServer` and `Set-PAAccount` in the entire codebase

## Test Coverage

**Unit:** Mock `Set-PAServer`, `Set-PAAccount`, and `Get-TUACMEConfig`; verify correct values are passed.

**Integration:** Verify that after calling these functions, `Get-PAServer` and `Get-PAAccount` return the expected values.

**Scripts:** N/A
