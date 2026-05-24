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
| 2.01 | Use-TUACMEProdAccount switches server and account | TU-ACME/Private/Bootstrap/Use-TUACMEProdAccount.ps1 | tests/Unit/Bootstrap/UC-2.01.Tests.ps1 | Implemented |
| 2.02 | Use-TUACMEStagingAccount switches server and account | TU-ACME/Private/Bootstrap/Use-TUACMEStagingAccount.ps1 | tests/Unit/Bootstrap/UC-2.02.Tests.ps1 | Implemented |
| 2.03 | Use-TUACME*Account throws when config not initialized | TU-ACME/Private/Bootstrap/Use-TUACME{Prod,Staging}Account.ps1 | tests/Unit/Bootstrap/UC-2.03.Tests.ps1 | Implemented |
| 3.01 | Order calls Use-TUACMEProdAccount first | TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1 | tests/Unit/Certificates/UC-3.01.Tests.ps1 | Implemented |
| 3.02 | Order prompts for and validates domain | TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1 | tests/Unit/Certificates/UC-3.02.Tests.ps1 | Implemented |
| 3.03 | Order accepts optional SAN list | TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1 | tests/Unit/Certificates/UC-3.03.Tests.ps1 | Implemented |
| 3.04 | Order rejects unknown DNS plugin | TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1 | tests/Unit/Certificates/UC-3.04.Tests.ps1 | Implemented |
| 3.05 | Order aborts when plugin args missing | TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1 | tests/Unit/Certificates/UC-3.05.Tests.ps1 | Implemented |
| 3.06 | Order confirmation defaults to No | TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1 | tests/Unit/Certificates/UC-3.06.Tests.ps1 | Implemented |
| 3.07 | Order surfaces Posh-ACME failure | TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1 | tests/Unit/Certificates/UC-3.07.Tests.ps1 | Implemented |
| 3.08 | Order writes Event 1003 on success | TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1 | tests/Unit/Certificates/UC-3.08.Tests.ps1 | Implemented |
| 3.01 | Order calls Use-TUACMEProdAccount first | TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1 | tests/Unit/Certificates/UC-3.01.Tests.ps1 | Implemented |
| 3.02 | Order prompts for and validates domain | TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1 | tests/Unit/Certificates/UC-3.02.Tests.ps1 | Implemented |
| 3.03 | Order accepts optional SAN list | TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1 | tests/Unit/Certificates/UC-3.03.Tests.ps1 | Implemented |
| 3.04 | Order rejects unknown plugin | TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1 | tests/Unit/Certificates/UC-3.04.Tests.ps1 | Implemented |
| 3.05 | Order aborts when plugin args missing | TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1 | tests/Unit/Certificates/UC-3.05.Tests.ps1 | Implemented |
| 3.06 | Order confirmation defaults to No | TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1 | tests/Unit/Certificates/UC-3.06.Tests.ps1 | Implemented |
| 3.07 | Order surfaces Posh-ACME failure | TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1 | tests/Unit/Certificates/UC-3.07.Tests.ps1 | Implemented |
| 3.08 | Order writes Event 1003 on success | TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1 | tests/Unit/Certificates/UC-3.08.Tests.ps1 | Implemented |
| 4.01 | Dry-run uses staging then restores prod | TU-ACME/Private/Certificates/Invoke-DryRunOrder.ps1 | tests/Unit/Certificates/UC-4.01.Tests.ps1 | Implemented |
| 4.02 | Dry-run restores prod even when ordering fails | TU-ACME/Private/Certificates/Invoke-DryRunOrder.ps1 | tests/Unit/Certificates/UC-4.02.Tests.ps1 | Implemented |
| 4.03 | Dry-run tags issued cert as TU-ACME-DryRun | TU-ACME/Private/Certificates/Invoke-DryRunOrder.ps1 | tests/Unit/Certificates/UC-4.03.Tests.ps1 | Implemented |
| 5.01 | Dashboard calls Use-TUACMEProdAccount first | TU-ACME/Private/Certificates/Invoke-CertificateDashboard.ps1 | tests/Unit/Certificates/UC-5.01.Tests.ps1 | Implemented |
| 5.02 | Dashboard hides dry-run certs by default | TU-ACME/Private/Certificates/Invoke-CertificateDashboard.ps1 | tests/Unit/Certificates/UC-5.02.Tests.ps1 | Implemented |
| 5.03 | Dashboard d hotkey reveals dry-runs pane | TU-ACME/Private/Certificates/Invoke-CertificateDashboard.ps1 | tests/Unit/Certificates/UC-5.03.Tests.ps1 | Implemented |
| 5.04 | Dashboard colors certs by expiry | TU-ACME/Private/Certificates/Invoke-CertificateDashboard.ps1 | tests/Unit/Certificates/UC-5.04.Tests.ps1 | Implemented |
| 5.05 | Dashboard respects DefaultSort config | TU-ACME/Private/Certificates/Invoke-CertificateDashboard.ps1 | tests/Unit/Certificates/UC-5.05.Tests.ps1 | Implemented |
| 5.06 | Dashboard shows empty-state when no certs | TU-ACME/Private/Certificates/Invoke-CertificateDashboard.ps1 | tests/Unit/Certificates/UC-5.06.Tests.ps1 | Implemented |
| 5.07 | Dashboard e hotkey opens Export menu | TU-ACME/Private/Certificates/Invoke-CertificateDashboard.ps1 | tests/Unit/Certificates/UC-5.07.Tests.ps1 | Implemented |
| 11.01 | Log viewer reads TU-ACME provider events | TU-ACME/Private/Logs/Invoke-LogViewer.ps1 | tests/Unit/Logs/UC-11.01.Tests.ps1 | Implemented |
| 11.02 | Log viewer export prompts before overwriting | TU-ACME/Private/Logs/Invoke-LogViewer.ps1 | tests/Unit/Logs/UC-11.02.Tests.ps1 | Implemented |
| 11.03 | Log viewer is a no-op on non-Windows | TU-ACME/Private/Logs/Invoke-LogViewer.ps1 | tests/Unit/Logs/UC-11.03.Tests.ps1 | Implemented |
