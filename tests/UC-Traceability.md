# UC-til-Test sporbarhedsmatrix

Hvert use case skal have mindst én happy-path test og én failure/cancel-path test.

| UC | Titel | Test-fil | Happy | Failure/Cancel |
|---|---|---|---|---|
| UC-0.0 | Teknisk Stack og Specs | Module/TU-ACME.Module.Tests.ps1 | psd1 metadata | — |
| UC-0.1 | Administratorrettigheder | Helpers/Get-AdminStatus.Tests.ps1 | returns bool | mock false |
| UC-1.1 | Vis ACME-Konti | Accounts/Invoke-AccountMenu.Tests.ps1 | Show-Table called | — |
| UC-1.2 | Opret ACME-Konto | Accounts/Invoke-AccountMenu.Tests.ps1 | New-PAAccount called | ESC cancels |
| UC-1.3 | Skift Aktiv Konto | Accounts/Invoke-AccountMenu.Tests.ps1 | Set-PAAccount called | ESC + empty list |
| UC-1.4 | Staging Skift | Accounts/Invoke-AccountMenu.Tests.ps1 | Set-PAServer LE_STAGE | Set-PAServer LE_PROD |
| UC-2.1 | Indtast Domænenavn | Certificates/Invoke-OrderCertificate.Tests.ps1 | valid domain accepted | — |
| UC-2.2 | Bestil Certifikat | Certificates/Invoke-OrderCertificate.Tests.ps1 | Show-Spinner called | exception path |
| UC-3.1 | Vis DNS-Plugins | Certificates/Invoke-OrderCertificate.Tests.ps1 | plugin returned | ESC = null |
| UC-3.2 | Maskeret Credentials | Helpers/ConvertTo-MaskedInput.Tests.ps1 | chars + Enter | ESC = null |
| UC-3.3 | Gem Credentials | Helpers/Invoke-AcmeDnsSetup.Tests.ps1 | Export-Clixml called | — |
| UC-3.4 | DNS-01 Challenge | Certificates/Invoke-OrderCertificate.Tests.ps1 | DnsSleep 120 default | custom 300 |
| UC-3.5 | ACME-DNS Support | Helpers/Invoke-AcmeDnsSetup.Tests.ps1 | register + save | REST error = null |
| UC-4.1 | Dashboard Certifikater | Certificates/Invoke-CertificateDashboard.Tests.ps1 | Show-Table called | no certs = early return |
| UC-4.2 | Sortering Filtrering | Certificates/Invoke-CertificateDashboard.Tests.ps1 | — | — |
| UC-4.3 | Certifikat Detaljer | Certificates/Invoke-CertificateDashboard.Tests.ps1 | detail view shown | ESC exits detail |
| UC-5.1 | Opret Scheduled Task | Automation/Invoke-ScheduledTaskSetup.Tests.ps1 | Register-ScheduledTask | not admin + task exists + throws |
| UC-5.2 | Konfigurer SMTP | Automation/Invoke-SMTPConfig.Tests.ps1 | Set-TUACMEConfig | — |
| UC-5.3 | Test SMTP | Automation/Invoke-SMTPConfig.Tests.ps1 | Send-TUACMEMail | Send-MailMessage throws |
| UC-5.4 | Baggrundsfornyelse | Scripts/Invoke-RenewalBackground.Tests.ps1 | structure + EventId 1001 | EventId 3001 + mail |
| UC-6.1 | Eksporter PFX | Export/Invoke-ExportMenu.Tests.ps1 | — | — |
| UC-6.2 | Eksporter PEM | Export/Invoke-ExportMenu.Tests.ps1 | Copy-Item ×3 | mkdir when missing |
| UC-6.3 | Importer Windows Store | Export/Invoke-ExportMenu.Tests.ps1 | Import-PfxCertificate | not admin = skip |
| UC-7.1 | Vis Logfiler | Logs/Invoke-LogViewer.Tests.ps1 | pager opens | no files = return |
| UC-7.2 | Eksporter Logfiler | Logs/Invoke-LogViewer.Tests.ps1 | Copy-Item called | — |
| UC-8.1 | Scan IIS Bindings | IIS/Invoke-IISMenu.Tests.ps1 | Show-Table called | no bindings |
| UC-8.2 | Kobl Certifikat IIS | IIS/Invoke-IISMenu.Tests.ps1 | Set-WebBinding | no certs |
| UC-8.3 | Post-Renewal Plugin | IIS/Invoke-IISMenu.Tests.ps1 | Set-PAConfig called | script not found |
| UC-8.4 | Automatisk IIS | Scripts/Posh-ACME-IIS-Plugin.Tests.ps1 | Set-WebBinding | missing thumbprint = exit 0 |

## Åbne huller

- UC-4.2 Sortering/filtrering: ingen test for Sort-Object path — tilføj til `Invoke-CertificateDashboard.Tests.ps1`
- UC-6.1 PFX: password mismatch og permission error ikke testet — tilføj `_Export-PFX` tests
- Alle "tryk en tast"-flows antaget stubbet via `Invoke-ConsoleWaitKey` mock

## Kvalitetsgate

- Alle tests skal bestå på Windows PowerShell 5.1
- Tests mærket `LiveExternal` køres ikke i CI (kræver netværk + LE-staging)
- Minimum: én `It` per UC happy path + én per failure/cancel path for høj-prioritet UCs
