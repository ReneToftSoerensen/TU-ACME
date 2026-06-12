# UC-1.01: Module Import

## Narrative

As an **operator**, I want to **import TU-ACME without errors**, so that **I can access all public cmdlets and begin certificate operations**.

## Acceptance Criteria

- [x] `Import-Module TU-ACME` completes without errors
- [x] All public cmdlets are available after import (`Get-Command -Module TU-ACME`)
- [x] The module version is readable from the manifest
- [x] No initialization errors are logged to Event Log

## Implementation Notes

- Module manifest: `TU-ACME.psd1`
- Module entry point: `TU-ACME.psm1`
- Public cmdlets exported via `FunctionsToExport` in manifest
- First-run check happens during `Initialize-TUACMEEnvironment` (called from `.psm1`)

## Test Coverage

**Unit:** Mock `Initialize-TUACMEEnvironment` and verify manifest parsing.

**Integration:** Import the module and verify `Get-Command -Module TU-ACME` returns expected cmdlets.

**Scripts:** N/A
