# UC-0.1: Kontrol af administrator-rettigheder ved opstart

**Kategori:** System  
**Prioritet:** Høj

## Mål
At sikre, at administrative funktioner (såsom IIS-ændringer og Scheduled Tasks) kun er tilgængelige, hvis TUI'en kører med forhøjede rettigheder.

## Aktører
- Systemadministrator (Admin)
- Overvåger/Tekniker (ReadOnly)

## Prækonditioner
- TUI-applikationen er installeret og klar til opstart.

## Hovedforløb
1. TUI startes op.
2. Systemet undersøger, om den nuværende PowerShell-proces kører som Administrator.
3. Hvis **ikke** administrator:
   - Systemet viser en **rød advarselsbjælke** øverst i TUI'en:  
     `KØRER IKKE SOM ADMINISTRATOR - Administrative funktioner er deaktiveret`
   - Menuer tilhørende UC-5 (Automatisering) og UC-8 (IIS Integration) deaktiveres eller skjules.
4. Hvis administrator: TUI startes med fuld adgang til alle menuer og funktioner.

## Postkonditioner
- TUI'en er startet med korrekt adgangsniveau for den aktuelle bruger.

## Alternative forløb
- **3a:** Brugeren genstarter TUI som administrator → Fuld adgang gives.

## Tekniske noter
- Brug `[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)` til at tjekke rettigheder.
