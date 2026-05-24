# UC Traceability Matrix

This file tracks every atomic use case in `Usecases/` together with the implementation file and Pester test file that satisfies it. Each row should map one UC to exactly one Pester `Describe` block.

| UC ID | Title | Implementation file | Test file | Status |
|---|---|---|---|---|
| 1.01 | Detect uninitialized config triggers wizard | TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1 | tests/Unit/Bootstrap/UC-1.01.Tests.ps1 | Implemented |
| 1.02 | Skip wizard when already initialized | TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1 | tests/Unit/Bootstrap/UC-1.02.Tests.ps1 | Implemented |
| 1.03 | Force re-init bypasses initialized flag | TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1 | tests/Unit/Bootstrap/UC-1.03.Tests.ps1 | Implemented |
| 1.04 | Prompt and validate prod directory URL | TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1 | tests/Unit/Bootstrap/UC-1.04.Tests.ps1 | Implemented |
| 1.05 | Prompt and validate staging directory URL | TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1 | tests/Unit/Bootstrap/UC-1.05.Tests.ps1 | Implemented |
| 1.06 | Prompt and validate contact email | TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1 | tests/Unit/Bootstrap/UC-1.06.Tests.ps1 | Implemented |
| 1.07 | Confirmation summary defaults to No | TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1 | tests/Unit/Bootstrap/UC-1.07.Tests.ps1 | Implemented |
| 1.08 | Create prod ACME account | TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1 | tests/Unit/Bootstrap/UC-1.08.Tests.ps1 | Implemented |
| 1.09 | Create staging ACME account | TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1 | tests/Unit/Bootstrap/UC-1.09.Tests.ps1 | Implemented |
| 1.10 | Persist config and log Event 1010 | TU-ACME/Private/Bootstrap/Initialize-TUACMEEnvironment.ps1 | tests/Unit/Bootstrap/UC-1.10.Tests.ps1 | Implemented |
