# UC-6.2: Eksportér certifikat til PEM/Key/Cert filer

**Kategori:** Eksport og Import  
**Prioritet:** Medium

## Mål
At eksportere rå certifikatfiler til Linux-baserede systemer, NGINX, Apache, firewalls eller andre systemer, der ikke bruger PFX-format.

## Aktører
- Systemadministrator (Admin)

## Prækonditioner
- Certifikatet er bestilt og administreres af Posh-ACME (UC-2.2).

## Hovedforløb
1. Brugeren vælger et certifikat i oversigten (UC-4.1 eller UC-4.3).
2. Brugeren vælger "Eksportér" → "Eksportér til PEM".
3. TUI'en prompter for en destinations-mappe:  
   `Gem filer i mappen: C:\Certs\eksempel\`
4. Systemet eksporterer og gemmer tre filer:
   - `cert.crt` — Selve certifikatet (PEM-format)
   - `cert.key` — Den private nøgle (PEM-format)
   - `chain.crt` — CA-certifikatkæden (PEM-format)
5. Succes-besked vises:
   ```
   [OK] Filer gemt i: C:\Certs\eksempel\
     - cert.crt
     - cert.key
     - chain.crt
   ```

## Postkonditioner
- Tre PEM-filer er gemt i den angivne mappe, klar til overførsel til målsystem.

## Alternative forløb
- **3a:** Mappen eksisterer ikke → TUI spørger om den skal oprettes.
- **4a:** Skrive-rettigheder mangler → Fejlbesked med vejledning.

## Tekniske noter
- Posh-ACME gemmer allerede certifikatfiler i PEM-format i sin profil-mappe.
- Filer kan kopieres direkte fra: `$env:LOCALAPPDATA\Posh-ACME\<server>\<account>\<domain>\`
- Filnavne i Posh-ACME: `cert.cer`, `cert.key`, `chain.cer`, `fullchain.cer`
