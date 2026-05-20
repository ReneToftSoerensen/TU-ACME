# UC-to-Test traceability matrix

Every use case must have at least one happy-path test and one failure/cancel-path test.

| UC | Title | Test file | Happy | Failure/Cancel |
|---|---|---|---|---|
| UC-0.0 | Technical Stack and Specs | Module/TU-ACME.Module.Tests.ps1 | psd1 metadata | — |
| UC-0.1 | Administrator privileges | Helpers/Get-AdminStatus.Tests.ps1 | returns bool | mock false |
| UC-1.1 | Show ACME accounts | Accounts/Invoke-AccountMenu.Tests.ps1 | Show-Table called | — |
| UC-1.2 | Create ACME account | Accounts/Invoke-AccountMenu.Tests.ps1 | New-PAAccount called | ESC cancels |
| UC-1.3 | Switch active account | Accounts/Invoke-AccountMenu.Tests.ps1 | Set-PAAccount called | ESC + empty list |
| UC-1.4 | Staging switch | Accounts/Invoke-AccountMenu.Tests.ps1 | Set-PAServer LE_STAGE | Set-PAServer LE_PROD |
| UC-2.1 | Enter domain name | Certificates/Invoke-OrderCertificate.Tests.ps1 | valid domain accepted | — |
| UC-2.2 | Order certificate | Certificates/Invoke-OrderCertificate.Tests.ps1 | Show-Spinner called | exception path |
| UC-3.1 | Show DNS plugins | Certificates/Invoke-OrderCertificate.Tests.ps1 | plugin returned | ESC = null |
| UC-3.2 | Masked credentials | Helpers/ConvertTo-MaskedInput.Tests.ps1 | chars + Enter | ESC = null |
| UC-3.3 | Save credentials | Helpers/Invoke-AcmeDnsSetup.Tests.ps1 | Export-Clixml called | — |
| UC-3.4 | DNS-01 challenge | Certificates/Invoke-OrderCertificate.Tests.ps1 | DnsSleep 120 default | custom 300 |
| UC-3.5 | ACME-DNS support | Helpers/Invoke-AcmeDnsSetup.Tests.ps1 | register + save | REST error = null |
| UC-4.1 | Certificate dashboard | Certificates/Invoke-CertificateDashboard.Tests.ps1 | Show-Table called | no certs = early return |
| UC-4.2 | Sorting and filtering | Certificates/Invoke-CertificateDashboard.Tests.ps1 | — | — |
| UC-4.3 | Certificate details | Certificates/Invoke-CertificateDashboard.Tests.ps1 | detail view shown | ESC exits detail |
| UC-5.1 | Create Scheduled Task | Automation/Invoke-ScheduledTaskSetup.Tests.ps1 | Register-ScheduledTask | not admin + task exists + throws |
| UC-5.2 | Configure SMTP | Automation/Invoke-SMTPConfig.Tests.ps1 | Set-TUACMEConfig | — |
| UC-5.3 | Test SMTP | Automation/Invoke-SMTPConfig.Tests.ps1 | Send-TUACMEMail | Send-MailMessage throws |
| UC-5.4 | Background renewal | Scripts/Invoke-RenewalBackground.Tests.ps1 | structure + EventId 1001 | EventId 3001 + mail |
| UC-6.1 | Export PFX | Export/Invoke-ExportMenu.Tests.ps1 | — | — |
| UC-6.2 | Export PEM | Export/Invoke-ExportMenu.Tests.ps1 | Copy-Item x3 | mkdir when missing |
| UC-6.3 | Import to Windows Store | Export/Invoke-ExportMenu.Tests.ps1 | Import-PfxCertificate | not admin = skip |
| UC-7.1 | View log files | Logs/Invoke-LogViewer.Tests.ps1 | pager opens | no files = return |
| UC-7.2 | Export log files | Logs/Invoke-LogViewer.Tests.ps1 | Copy-Item called | — |
| UC-8.1 | Scan IIS bindings | IIS/Invoke-IISMenu.Tests.ps1 | Show-Table called | no bindings |
| UC-8.2 | Bind certificate to IIS | IIS/Invoke-IISMenu.Tests.ps1 | Set-WebBinding | no certs |
| UC-8.3 | Post-Renewal Plugin | IIS/Invoke-IISMenu.Tests.ps1 | Set-PAConfig called | script not found |
| UC-8.4 | Automatic IIS update | Scripts/Posh-ACME-IIS-Plugin.Tests.ps1 | Set-WebBinding | missing thumbprint = exit 0 |

## Open gaps

- UC-4.2 sorting/filtering: no test for Sort-Object path — add to `Invoke-CertificateDashboard.Tests.ps1`
- UC-6.1 PFX: password mismatch and permission error not tested — add `_Export-PFX` tests
- All "press any key" flows are assumed stubbed via `Invoke-ConsoleWaitKey` mock

## Quality gate

- All tests must pass on Windows PowerShell 5.1
- Tests tagged `LiveExternal` are not run in CI (requires network + LE staging)
- Minimum: one `It` per UC happy path + one per failure/cancel path for high-priority UCs
