# UC-1.3: Skift aktiv ACME-konto

**Kategori:** Kontostyring  
**Prioritet:** Høj

## Mål
At vælge, hvilken af de registrerede konti der skal være den aktive i den nuværende Posh-ACME-konfiguration.

## Aktører
- Systemadministrator (Admin)

## Prækonditioner
- Mindst to ACME-konti er registreret (UC-1.1).

## Hovedforløb
1. Brugeren navigerer til listen over eksisterende konti (UC-1.1).
2. Brugeren markerer den ønskede konto med piletasterne.
3. Brugeren vælger "Sæt som aktiv" (Enter eller dedikeret tast).
4. Appen kalder `Set-PAAccount` med den valgte kontos ID.
5. Statusbaren i bunden af TUI'en opdateres med den nye aktive konto.

## Postkonditioner
- Den valgte konto er nu aktiv og bruges ved alle efterfølgende certifikat-operationer.

## Alternative forløb
- **4a:** Fejl ved kontoskift → Fejlbesked vises, aktiv konto forbliver uændret.

## Tekniske noter
- PowerShell-kommando: `Set-PAAccount -ID "<account-id>"`
