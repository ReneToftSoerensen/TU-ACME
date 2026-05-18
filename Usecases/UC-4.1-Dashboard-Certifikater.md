# UC-4.1: Vis interaktiv tabel over certifikater (Farvekodet)

**Kategori:** Dashboard  
**Prioritet:** Høj

## Mål
Give et hurtigt og farvekodet overblik over alle certifikater administreret af Posh-ACME.

## Aktører
- Systemadministrator (Admin)
- Overvåger/Tekniker (ReadOnly)

## Prækonditioner
- Posh-ACME er installeret. Nul eller flere certifikater kan eksistere.

## Hovedforløb
1. TUI'en indlæser certifikater via `Get-PACertificate`.
2. Certifikaterne præsenteres i en tabel med kolonner:
   ```
   Domæne              Udloebsdato    Dage tilbage    Status
   ----------------------------------------------------------------
   eksempel.dk         2026-08-18     92              [OK]
   test.dk             2026-06-02     15              [UDLOEBER SNART]
   gammel.dk           2026-05-10     -8              [UDLOEBET]
   ```
3. Farvekodning baseret på dage tilbage:
   - **> 30 dage:** Grøn tekst
   - **≤ 30 dage:** Gul tekst
   - **Udløbet (< 0 dage):** Rød tekst (evt. blinkende)
4. Tabellen opdateres ved hvert besøg til dashboardet.

## Postkonditioner
- Brugeren har overblik over alle certifikaters status.

## Alternative forløb
- **1a:** Ingen certifikater fundet → Besked: `Ingen certifikater. Bestil dit første certifikat (UC-2.1).`

## Tekniske noter
- PowerShell-kommando: `Get-PACertificate -List`
- Farver sættes med `Write-Host -ForegroundColor Green/Yellow/Red`
- Dage beregnes: `($cert.NotAfter - (Get-Date)).Days`
