# UC-3.1: Vis understøttede DNS-plugins i menu

**Kategori:** DNS-Plugins og Credentials  
**Prioritet:** Høj

## Mål
Give brugeren en interaktiv liste over de mange DNS-plugins, Posh-ACME understøtter.

## Aktører
- Systemadministrator (Admin)

## Prækonditioner
- Posh-ACME er installeret med plugins tilgængelige.

## Hovedforløb
1. Brugeren er i gang med certifikatbestilling og skal vælge valideringsmetode.
2. TUI'en indlæser listen over tilgængelige plugins fra Posh-ACMEs plugin-mappe.
3. Plugins præsenteres i en rullbar, søgbar liste, f.eks.:
   ```
   Vælg DNS-plugin (brug piletaster, søg med /):
   > Azure
     Cloudflare
     Route53
     GoDaddy
     Manual
     ...
   ```
4. Brugeren navigerer med piletasterne og bekræfter valget med Enter.

## Postkonditioner
- Et DNS-plugin er valgt og processen fortsætter til UC-3.2.

## Alternative forløb
- **2a:** Plugin-mappen ikke fundet → Fejlbesked, kun "Manual" tilbydes som fallback.
- **4a:** Brugeren vælger "Manual" → TUI guider til manuel DNS-validering med kopiérbar TXT-record.

## Tekniske noter
- Plugin-liste hentes via: `Get-PAPlugin` eller ved at liste `.ps1`-filer i Posh-ACMEs plugin-mappe.
- Søgning i listen filtrerer øjeblikkeligt ved tastatur-input efter `/`.
