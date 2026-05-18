# UC-6.3: Importér certifikat direkte til Windows Certificate Store

**Kategori:** Eksport og Import  
**Prioritet:** Høj

## Mål
At installere certifikatet på den lokale Windows-maskine, så det er klar til brug i IIS eller andre Windows-tjenester.

## Aktører
- Systemadministrator (Admin)

## Prækonditioner
- TUI kører med administratorrettigheder (UC-0.1).
- Certifikatet er bestilt og administreres af Posh-ACME (UC-2.2).

## Hovedforløb
1. Brugeren vælger et certifikat i oversigten og trykker "Importer til Windows Store".
2. TUI'en lader brugeren vælge certifikatlager via en menu:
   ```
   Vælg certifikatlager:
   > Personal (My)        - Standard for IIS og de fleste tjenester
     Web Hosting           - Optimeret lager til mange IIS-certifikater
   ```
3. Brugeren bekræfter valget.
4. Systemet importerer certifikatet i `LocalMachine`-lageret (ikke `CurrentUser`) med den private nøgle.
5. Succes-besked vises:
   ```
   [OK] Certifikat importeret til LocalMachine\My
   Thumbprint: A1B2C3D4E5F6...
   ```

## Postkonditioner
- Certifikatet er installeret i Windows Certificate Store med den private nøgle.
- IIS og andre Windows-tjenester kan nu bruge certifikatet via thumbprint.

## Alternative forløb
- **4a:** Certifikat allerede installeret (samme thumbprint) → Bekræftelse vises, ingen fejl.
- **4b:** Fejl ved import → Præcis fejlbesked fra .NET/Windows.

## Tekniske noter
- PowerShell-kommando: `Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation "Cert:\LocalMachine\My" -Password $securePassword`
- Web Hosting-lageret: `Cert:\LocalMachine\WebHosting`
- Private nøgle skal markeres som eksporterbar hvis certifikatet skal kunne flyttes videre.
