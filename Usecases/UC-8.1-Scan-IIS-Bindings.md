# UC-8.1: Scan lokale IIS-sites og HTTPS-bindings

**Kategori:** IIS Integration  
**Prioritet:** Høj

## Mål
Identificere hvilke websteder på maskinen, der i øjeblikket kører med HTTPS, og hvilke certifikater de bruger.

## Aktører
- Systemadministrator (Admin)

## Prækonditioner
- TUI kører med administratorrettigheder (UC-0.1).
- IIS (Internet Information Services) er installeret på maskinen.
- PowerShell-modulet `WebAdministration` er tilgængeligt.

## Hovedforløb
1. Brugeren vælger "IIS-integration" → "Vis bindings".
2. Systemet importerer `WebAdministration`-modulet.
3. Systemet scanner alle IIS-websteder for HTTPS-bindings (port 443 og andre SSL-porte).
4. En tabel vises med:
   ```
   Site-navn         Binding              Thumbprint (nuværende)    Match i Posh-ACME?
   ---------------------------------------------------------------------------------
   Eksempel-site     https *:443:         A1B2C3D4E5F6...           Ja (eksempel.dk)
   Test-site         https *:8443:test    AABBCC112233...           Nej
   ```

## Postkonditioner
- Administratoren har overblik over alle IIS HTTPS-bindings og deres certifikatstatus.

## Alternative forløb
- **2a:** `WebAdministration`-modulet ikke fundet → Fejlbesked: `IIS er ikke installeret eller WebAdministration-modulet mangler.`
- **3a:** Ingen HTTPS-bindings fundet → Besked: `Ingen HTTPS-bindings fundet i IIS.`

## Tekniske noter
- PowerShell-kommandoer:
  ```powershell
  Import-Module WebAdministration
  Get-WebBinding -Protocol "https" | Select-Object bindingInformation, certificateHash
  ```
- Matching med Posh-ACME: sammenlign `certificateHash` (thumbprint) med `(Get-PACertificate -List).Thumbprint`
