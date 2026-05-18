# UC-3.3: Gem API-credentials krypteret på disken

**Kategori:** DNS-Plugins og Credentials  
**Prioritet:** Høj

## Mål
Gemme adgangskoderne på en måde, så kun systemet (og baggrundsopgaven) kan læse dem.

## Aktører
- Systemadministrator (Admin)

## Prækonditioner
- API-credentials er opsamlet som `SecureString` (UC-3.2).

## Hovedforløb
1. De indtastede følsomme parametre (fra UC-3.2) er allerede konverteret til `SecureString` i PowerShell.
2. Appen gemmer dem krypteret på disken via én af metoderne:
   - **Posh-ACMEs eget system:** Credentials gemmes som en hashtabel og overdrages direkte til `New-PACertificate` via `-PluginArgs`, hvor Posh-ACME håndterer kryptering med DPAPI.
   - **Supplerende lagring:** Konfigurationsfil gemmes med `Export-Clixml`, der bruger DPAPI-baseret kryptering (kun tilgængelig for den bruger/maskine, der gemte dem).
3. En bekræftelsesbesked vises: `Credentials gemt krypteret.`

## Postkonditioner
- Credentials er gemt krypteret og kan kun dekrypteres af den samme bruger/maskine.
- Baggrundsopgaven (UC-5.4) kan indlæse credentials uden brugerinteraktion.

## Alternative forløb
- **2a:** DPAPI ikke tilgængeligt (f.eks. Linux/ikke-Windows) → Fejlbesked og advarsel om manglende kryptering.

## Tekniske noter
- DPAPI kryptering: `$SecureString | ConvertFrom-SecureString` (maskin-bundet)
- `Export-Clixml` med `SecureString` bruger DPAPI automatisk.
- Krypterede filer bør gemmes i: `$env:LOCALAPPDATA\Posh-ACME\PluginData\`
