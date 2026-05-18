# UC-1.4: Hurtig skift til Staging/Test-miljø

**Kategori:** Kontostyring  
**Prioritet:** Høj

## Mål
At gøre det nemt at skifte til Let's Encrypt Staging-miljøet under test for at undgå rate-limits.

## Aktører
- Systemadministrator (Admin)

## Prækonditioner
- TUI'en er startet og viser statusbar i bunden.

## Hovedforløb
1. I TUI-bunden vises den aktive konto og server (f.eks. `Aktiv: admin@eks.dk | Let's Encrypt Production`).
2. Brugeren trykker på genvejstasten **F3** (eller vælger menupunkt "Skift til Staging").
3. Appen tjekker om en Let's Encrypt Staging-konto allerede eksisterer.
4. Hvis staging-konto eksisterer: Appen skifter øjeblikkeligt og statusbaren opdateres.
5. Statusbaren viser nu: `Aktiv: admin@eks.dk | Let's Encrypt STAGING`.

## Postkonditioner
- Aktiv ACME-server er Let's Encrypt Staging.

## Alternative forløb
- **3a:** Ingen staging-konto fundet → TUI guider brugeren til UC-1.2 med Let's Encrypt Staging forudvalgt.

## Tekniske noter
- Let's Encrypt Staging URL: `https://acme-staging-v02.api.letsencrypt.org/directory`
- Staging-certifikater er ikke tillid til af browsere, men er egnede til test.
