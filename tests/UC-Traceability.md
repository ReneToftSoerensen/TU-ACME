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
| 3.09 | Order cancels on Esc at any prompt | TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1 | tests/Unit/Certificates/UC-3.09.Tests.ps1 | Implemented |
| 4.01 | Dry-run uses staging then restores prod | TU-ACME/Private/Certificates/Invoke-DryRunOrder.ps1 | tests/Unit/Certificates/UC-4.01.Tests.ps1 | Implemented |
| 4.02 | Dry-run restores prod even when ordering fails | TU-ACME/Private/Certificates/Invoke-DryRunOrder.ps1 | tests/Unit/Certificates/UC-4.02.Tests.ps1 | Implemented |
| 4.03 | Dry-run tags issued cert as TU-ACME-DryRun | TU-ACME/Private/Certificates/Invoke-DryRunOrder.ps1 | tests/Unit/Certificates/UC-4.03.Tests.ps1 | Implemented |
| 4.04 | Dry-run cancels on Esc and restores prod | TU-ACME/Private/Certificates/Invoke-DryRunOrder.ps1 | tests/Unit/Certificates/UC-4.04.Tests.ps1 | Implemented |
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
| 6.01 | DNS plugin menu lists Get-PAPlugin entries | TU-ACME/Private/Certificates/Invoke-DnsPluginConfig.ps1 | tests/Unit/Certificates/UC-6.01.Tests.ps1 | Implemented |
| 6.02 | DNS plugin prompts mask secret-named parameters | TU-ACME/Private/Certificates/Invoke-DnsPluginConfig.ps1 | tests/Unit/Certificates/UC-6.02.Tests.ps1 | Implemented |
| 6.03 | DNS plugin save persists via Export-Clixml sidecar | TU-ACME/Private/Certificates/Invoke-DnsPluginConfig.ps1 | tests/Unit/Certificates/UC-6.03.Tests.ps1 | Implemented |
| 6.04 | DNS plugin Acme-Dns picks dedicated helper | TU-ACME/Private/Certificates/Invoke-DnsPluginConfig.ps1 | tests/Unit/Certificates/UC-6.04.Tests.ps1 | Implemented |
| 6.05 | Plugin menu offers HTTP-01 filter | TU-ACME/Private/Certificates/Invoke-DnsPluginConfig.ps1 | tests/Unit/Certificates/UC-6.05.Tests.ps1 | Implemented |
| 6.07 | Plugin menu uses two-tier flow with AllowSearch | TU-ACME/Private/Certificates/Invoke-DnsPluginConfig.ps1 | tests/Unit/Certificates/UC-6.07.Tests.ps1 | Implemented |
| 7.01 | SMTP saves config when summary confirmed | TU-ACME/Private/Automation/Invoke-SMTPConfig.ps1 | tests/Unit/Automation/UC-7.01.Tests.ps1 | Implemented |
| 7.02 | SMTP password persisted DPAPI-encrypted | TU-ACME/Private/Automation/Invoke-SMTPConfig.ps1 | tests/Unit/Automation/UC-7.02.Tests.ps1 | Implemented |
| 7.03 | Send-Test emits Event 1007 on success | TU-ACME/Private/Automation/Invoke-SMTPConfig.ps1 | tests/Unit/Automation/UC-7.03.Tests.ps1 | Implemented |
| 8.01 | Scheduled task setup prompts and persists | TU-ACME/Private/Automation/Invoke-ScheduledTaskSetup.ps1 | tests/Unit/Automation/UC-8.01.Tests.ps1 | Implemented |
| 8.02 | Scheduled task setup prompts before overwriting | TU-ACME/Private/Automation/Invoke-ScheduledTaskSetup.ps1 | tests/Unit/Automation/UC-8.02.Tests.ps1 | Implemented |
| 8.03 | Scheduled task setup registers via Register-ScheduledTask | TU-ACME/Private/Automation/Invoke-ScheduledTaskSetup.ps1 | tests/Unit/Automation/UC-8.03.Tests.ps1 | Implemented |
| 8.04 | Scheduled task runs as SYSTEM with highest run level | TU-ACME/Private/Automation/Invoke-ScheduledTaskSetup.ps1 | tests/Unit/Automation/UC-8.04.Tests.ps1 | Implemented |
| 8.05 | Scheduled task setup writes Event 1008 | TU-ACME/Private/Automation/Invoke-ScheduledTaskSetup.ps1 | tests/Unit/Automation/UC-8.05.Tests.ps1 | Implemented |
| 8.06 | Renewal script calls Use-TUACMEProdAccount first | TU-ACME/Scripts/Invoke-RenewalBackground.ps1 | tests/Scripts/Invoke-RenewalBackground.Tests.ps1 | Implemented |
| 8.07 | Renewal script writes Event 1001 per renewed cert | TU-ACME/Scripts/Invoke-RenewalBackground.ps1 | tests/Scripts/Invoke-RenewalBackground.Tests.ps1 | Implemented |
| 8.08 | Renewal script triggers IIS rebind when helper present | TU-ACME/Scripts/Invoke-RenewalBackground.ps1 | tests/Scripts/Invoke-RenewalBackground.Tests.ps1 | Implemented |
| 8.09 | Renewal script runs body inside loaded module's scope | TU-ACME/Scripts/Invoke-RenewalBackground.ps1 | tests/Scripts/Invoke-RenewalBackground.Tests.ps1 | Implemented |
| 8.10 | Renewal handles no-certs case as benign no-op | TU-ACME/Scripts/Invoke-RenewalBackground.ps1 | tests/Scripts/Invoke-RenewalBackground.Tests.ps1 | Implemented |
| 8.11 | Renewal FAILED mail body includes host, RunAs, ACME directory, message, stack trace | TU-ACME/Scripts/Invoke-RenewalBackground.ps1 | tests/Scripts/Invoke-RenewalBackground.Tests.ps1 | Implemented |
| 9.01 | IIS menu calls Use-TUACMEProdAccount first | TU-ACME/Private/IIS/Invoke-IISMenu.ps1 | tests/Unit/IIS/UC-9.01.Tests.ps1 | Implemented |
| 9.02 | IIS menu scans every binding without a Protocol filter | TU-ACME/Private/IIS/Invoke-IISMenu.ps1 | tests/Unit/IIS/UC-9.02.Tests.ps1 | Implemented |
| 9.03 | IIS menu joins bindings to certs by thumbprint | TU-ACME/Private/IIS/Invoke-IISMenu.ps1 | tests/Unit/IIS/UC-9.03.Tests.ps1 | Implemented |
| 9.04 | IIS rebind invokes Set-WebBinding with new hash | TU-ACME/Private/IIS/Invoke-IISMenu.ps1 | tests/Unit/IIS/UC-9.04.Tests.ps1 | Implemented |
| 9.05 | Update-IISBindingForCert continues on per-binding failure | TU-ACME/Scripts/Posh-ACME-IIS-Plugin.ps1 | tests/Scripts/Posh-ACME-IIS-Plugin.Tests.ps1 | Implemented |
| 9.06 | IIS rebind picker lists sites with their hostnames | TU-ACME/Private/IIS/Invoke-IISMenu.ps1 | tests/Unit/IIS/UC-9.06.Tests.ps1 | Implemented |
| 9.07 | IIS table lists every binding (HTTP and HTTPS) | TU-ACME/Private/IIS/Invoke-IISMenu.ps1 | tests/Unit/IIS/UC-9.07.Tests.ps1 | Implemented |
| 9.08 | IIS table shows certificate expiry on HTTPS rows | TU-ACME/Private/IIS/Invoke-IISMenu.ps1 | tests/Unit/IIS/UC-9.07.Tests.ps1 | Implemented |
| 9.09 | IIS table shows AD CS template name on HTTPS rows | TU-ACME/Private/IIS/Invoke-IISMenu.ps1 | tests/Unit/IIS/UC-9.07.Tests.ps1 | Implemented |
| 9.10 | Get-CertTemplateName parses AD CS v1/v2 template extensions | TU-ACME/Private/Helpers/Get-CertTemplateName.ps1 | tests/Unit/Helpers/Get-CertTemplateName.Tests.ps1 | Implemented |
| 9.11 | IIS menu orders new cert from site bindings (bundle / split, warn on non-FQDN) | TU-ACME/Private/IIS/Invoke-IISOrderFromBindings.ps1 | tests/Unit/IIS/UC-9.11.Tests.ps1 | Implemented |
| 9.12 | Test-IsFqdnHostname classifies FQDN vs single-label / IP / wildcard | TU-ACME/Private/Helpers/Test-IsFqdnHostname.ps1 | tests/Unit/Helpers/Test-IsFqdnHostname.Tests.ps1 | Implemented |
| 10.01 | Export PFX prompts overwrite and calls Export-PfxCertificate | TU-ACME/Private/Export/Invoke-ExportMenu.ps1 | tests/Unit/Export/UC-10.01.Tests.ps1 | Implemented |
| 10.02 | Export PEM concatenates chain and key | TU-ACME/Private/Export/Invoke-ExportMenu.ps1 | tests/Unit/Export/UC-10.02.Tests.ps1 | Implemented |
| 10.03 | Import to Windows store calls Import-PfxCertificate | TU-ACME/Private/Export/Invoke-ExportMenu.ps1 | tests/Unit/Export/UC-10.03.Tests.ps1 | Implemented |
