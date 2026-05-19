# UC-1.1: Vis liste over eksisterende ACME-konti

**Kategori:** Kontostyring  
**Prioritet:** Høj

## Mål
Give administratoren overblik over konfigurerede Let's Encrypt / ACME-konti.

## Aktører
- Systemadministrator (Admin)
- Overvåger/Tekniker (ReadOnly)

## Prækonditioner
- Posh-ACME er installeret og konfigureret med mindst én konto.

## Hovedforløb
1. Brugeren vælger "Kontostyring" i hovedmenuen.
2. TUI'en indlæser konti fra Posh-ACMEs profil-sti via `Get-PAAccount`.
3. En liste over registrerede e-mailadresser og deres tilhørende ACME-servere (Production/Staging) vises på skærmen.

## Postkonditioner
- Brugeren har overblik over alle registrerede ACME-konti.

## Alternative forløb
- **2a:** Ingen konti fundet → TUI'en viser besked: `Ingen ACME-konti fundet. Opret en ny konto (UC-1.2).`

## Tekniske noter
- PowerShell-kommando: `Get-PAAccount -List`
- Profil-sti typisk: `$env:LOCALAPPDATA\Posh-ACME`
