# UC-6.1: Eksportér certifikat til PFX-fil

**Kategori:** Eksport og Import  
**Prioritet:** Medium

## Mål
At gemme certifikatet som en passwordbeskyttet PFX-fil til brug på andre systemer (f.eks. andre Windows-servere, load balancers, firewalls).

## Aktører
- Systemadministrator (Admin)

## Prækonditioner
- Certifikatet er bestilt og administreres af Posh-ACME (UC-2.2).

## Hovedforløb
1. Brugeren vælger et certifikat i oversigten (UC-4.1 eller UC-4.3).
2. Brugeren vælger "Eksportér" → "Eksportér til PFX".
3. TUI'en prompter for destinations-sti:  
   `Gem PFX som (fuld sti): C:\Certs\eksempel.pfx`
4. TUI'en prompter for adgangskode til PFX (inputtet maskeres, UC-3.2):  
   `PFX-adgangskode: ****`  
   `Bekræft adgangskode: ****`
5. Systemet genererer PFX-filen via Posh-ACME.
6. Succes-besked: `PFX gemt: C:\Certs\eksempel.pfx`

## Postkonditioner
- En passwordbeskyttet PFX-fil er gemt på den angivne sti.

## Alternative forløb
- **4a:** Adgangskoderne matcher ikke → Fejlbesked og brugeren bedes prøve igen.
- **5a:** Skrive-rettigheder mangler til destinationsmappen → Fejlbesked med vejledning.

## Tekniske noter
- Posh-ACME gemmer PFX-filen via `Export-PfxCertificate` eller `openssl` afhængig af certifikattypen.
- Alternativt: `[System.Security.Cryptography.X509Certificates.X509Certificate2]::Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $password)`
