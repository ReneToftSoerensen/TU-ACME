# UC-8.2: Kobl certifikat til IIS-endpoints manuelt via TUI

**Kategori:** IIS Integration  
**Prioritet:** Høj

## Mål
At opdatere en eller flere IIS HTTPS-bindings med det nyeste certifikat direkte fra terminalen.

## Aktører
- Systemadministrator (Admin)

## Prækonditioner
- TUI kører med administratorrettigheder (UC-0.1).
- Et certifikat er valgt i oversigten (UC-4.1 / UC-4.3).
- IIS-scan er tilgængelig (UC-8.1).

## Hovedforløb
1. Brugeren vælger et certifikat i oversigten (UC-4.1) og trykker "Tildel til IIS".
2. Systemet viser listen over scannede IIS-endpoints (UC-8.1).
3. Brugeren markerer de ønskede endpoints med piletasterne og trykker **Mellemrum** for at toggle:
   ```
   Vælg IIS-endpoints (Mellemrum = toggle, Enter = bekræft):
   [x] Eksempel-site     https *:443:
   [ ] Test-site          https *:8443:test
   ```
4. Brugeren trykker **Enter** for at bekræfte.
5. Appen importerer certifikatet til Windows Certificate Store (UC-6.3).
6. Appen opdaterer de valgte IIS-bindings med det nye thumbprint:
   ```powershell
   Set-WebBinding -Name "Eksempel-site" -BindingInformation "*:443:" -PropertyName "certificateHash" -Value $newThumbprint
   ```
7. Succes-besked vises for hvert opdateret endpoint.

## Postkonditioner
- De valgte IIS-bindings bruger nu det nyeste certifikat.

## Alternative forløb
- **4a:** Ingen endpoints valgt → Afbrydes, ingen ændringer.
- **6a:** Fejl ved opdatering af en binding → Fejlbesked for det specifikke endpoint; andre endpoints opdateres stadig.

## Tekniske noter
- Kræver `Import-Module WebAdministration` og `Set-WebBinding`.
- Certifikatet skal være importeret til `LocalMachine\My` eller `LocalMachine\WebHosting` (UC-6.3) inden IIS-binding opdateres.
