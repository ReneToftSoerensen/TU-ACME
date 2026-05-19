# UC-5.1: Opret Windows Scheduled Task til natlig kørsel

**Kategori:** Automatisering  
**Prioritet:** Høj

## Mål
Oprette den Windows Scheduled Task, der skal afvikle den automatiske fornyelse i baggrunden.

## Aktører
- Systemadministrator (Admin)

## Prækonditioner
- TUI kører med administratorrettigheder (UC-0.1).
- Posh-ACME er installeret og mindst ét certifikat administreres.

## Hovedforløb
1. Brugeren vælger "Automatisering" → "Opret Scheduled Task".
2. TUI'en prompter for konfigurationsparametre:
   - **Kørselstidspunkt** (standard: `03:00`)
   - **Brugerkonto** til at køre opgaven: `SYSTEM` / `Specifik bruger`
3. TUI'en viser en opsummering og beder om bekræftelse.
4. Systemet genererer en Scheduled Task med:
   - Navn: `Posh-ACME-AutoRenewal`
   - Trigger: Daglig kl. valgt tidspunkt
   - Handling: `powershell.exe -NonInteractive -File "C:\...\Invoke-RenewalBackground.ps1"`
   - Kørselskonto: Den valgte konto
5. Task'en oprettes via `Register-ScheduledTask` og bekræftes over for brugeren.

## Postkonditioner
- Windows Scheduled Task er oprettet og aktiv.
- Automatisk fornyelse vil køre nat efter nat.

## Alternative forløb
- **2a:** Brugeren vælger "Specifik bruger" → Promptes for brugernavn og adgangskode.
- **5a:** Task eksisterer allerede → TUI spørger om den skal overskrives.
- **5b:** Fejl ved oprettelse → Præcis fejlbesked vises.

## Tekniske noter
- PowerShell-kommando: `Register-ScheduledTask -TaskName "Posh-ACME-AutoRenewal" -Action $action -Trigger $trigger -RunLevel Highest`
- Task skal køre med "Run whether user is logged on or not" for headless-drift.
