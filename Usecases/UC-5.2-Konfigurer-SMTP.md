# UC-5.2: Konfigurer og gem SMTP-indstillinger til e-mail

**Kategori:** Automatisering  
**Prioritet:** Høj

## Mål
Konfigurere de SMTP-oplysninger, der skal bruges til at sende advarselsmails, hvis den automatiske fornyelse fejler.

## Aktører
- Systemadministrator (Admin)

## Prækonditioner
- TUI kører med administratorrettigheder (UC-0.1).

## Hovedforløb
1. Brugeren vælger "Konfigurer fejladvisering".
2. TUI'en prompter for følgende parametre:
   - **SMTP-Server** (f.eks. `smtp.office365.com`)
   - **Port** (standard: `587`)
   - **Afsender-e-mail** (f.eks. `noreply@eksempel.dk`)
   - **Modtager-e-mail** (administrator)
   - **Kræver SSL/TLS?** [J/N]
   - **Kræver login?** [J/N]
3. Hvis login kræves: Promptes for brugernavn og adgangskode (adgangskoden maskeres, UC-3.2).
4. Alle indstillinger gemmes krypteret i en central JSON-konfigurationsfil (adgangskoden gemmes som krypteret `SecureString`, UC-3.3).
5. Besked vises: `SMTP-konfiguration gemt.`

## Postkonditioner
- SMTP-indstillinger er gemt krypteret og klar til brug i baggrundsscriptet (UC-5.4).

## Alternative forløb
- **3a:** Login ikke krævet → Spring over brugernavn/adgangskode-prompt.

## Tekniske noter
- Konfigurationsfil gemmes som: `$env:ProgramData\PoshACME-TUI\smtp-config.xml` (krypteret med Export-Clixml).
- `Send-MailMessage` eller .NET `System.Net.Mail.SmtpClient` bruges til afsendelse.
