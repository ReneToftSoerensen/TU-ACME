# UC-4.2: Sortering og filtrering af certifikatlisten

**Kategori:** Dashboard  
**Prioritet:** Medium

## Mål
Gøre det nemt at finde specifikke certifikater på maskiner med mange domæner.

## Aktører
- Systemadministrator (Admin)
- Overvåger/Tekniker (ReadOnly)

## Prækonditioner
- Dashboard med certifikatliste er vist (UC-4.1).
- Mindst ét certifikat eksisterer.

## Hovedforløb
1. Brugeren er i dashboard-tabellen (UC-4.1).
2. **Søgning:** Brugeren trykker `/` for at aktivere søgefeltet.
   - En input-linje vises i bunden: `Sog: _`
   - Tabellen filtreres øjeblikkeligt ved hvert tastetryk.
   - Tryk ESC for at rydde søgningen og vende tilbage til fuld liste.
3. **Sortering:** Brugeren trykker `S` for at cykle mellem sorteringsmuligheder:
   - Sortér efter udløbsdato (stigende) ← standard
   - Sortér efter udløbsdato (faldende)
   - Sortér alfabetisk (A-Å)
4. Den aktive sorteringsmetode vises i tabelens header.

## Postkonditioner
- Tabellen viser den filtrerede og/eller sorterede liste.

## Alternative forløb
- **2a:** Ingen søgeresultater → Besked: `Ingen certifikater matcher søgningen.`

## Tekniske noter
- Filtrering sker på `Domain`-kolonnen (case-insensitiv).
- Sortering implementeres med PowerShell `Sort-Object`.
