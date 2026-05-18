# UC-8.4: Automatisk IIS-opdatering via Post-Renewal script

**Kategori:** IIS Integration  
**Prioritet:** Høj

## Mål
Den automatiske baggrundsproces, der sikrer, at IIS-bindings altid har det nyeste certifikat, uden at administratoren skal røre en finger.

## Aktører
- Posh-ACME (automatisk trigger efter fornyelse)
- Windows Task Scheduler (indirekte via UC-5.4)

## Prækonditioner
- Scheduled Task er oprettet og kører `Submit-Renewal` (UC-5.1 / UC-5.4).
- Post-renewal plugin er registreret i Posh-ACME (UC-8.3).
- Certifikatet er tidligere tilknyttet IIS-bindings (UC-8.2).

## Hovedforløb
1. Posh-ACME (afviklet af Task Scheduler, UC-5.4) gennemfører en succesfuld fornyelse af certifikatet.
2. Posh-ACME trigger automatisk det registrerede post-script (`Posh-ACME-IIS-Plugin.ps1`) og sender følgende parametre:
   - Det **nye** certifikat (sti og thumbprint)
   - Det **gamle** certifikat (thumbprint)
3. Post-scriptet importerer automatisk det nye certifikat til Windows Certificate Store (`LocalMachine\My`).
4. Post-scriptet scanner alle IIS-bindings for det gamle thumbprint.
5. For hver binding der matcher det gamle thumbprint:
   - Binding opdateres med det nye thumbprint.
6. Hændelsen logges i Windows Event Log:
   ```
   Source:  Posh-ACME-TUI
   Message: IIS-binding for eksempel.dk (*:443:) opdateret.
            Gammelt thumbprint: A1B2C3...
            Nyt thumbprint:     D4E5F6...
   ```

## Postkonditioner
- Alle IIS-bindings er opdateret med det nyeste certifikat.
- IIS behøver ikke genudsendelse (IIS binder automatisk det nye certifikat).
- Hændelsen er logget i Windows Event Log.

## Alternative forløb
- **4a:** Ingen IIS-bindings bruger det gamle thumbprint → Scriptet afslutter lydløst uden ændringer.
- **5a:** Fejl ved opdatering af en specifik binding → Fejlen logges i Windows Event Log; øvrige bindings opdateres stadig.

## Tekniske noter
- Post-scriptet modtager parametre: `$OldCertThumbprint`, `$NewCertPath`, `$NewCertThumbprint`
- PowerShell-kommandoer:
  ```powershell
  Import-Module WebAdministration
  Get-WebBinding -Protocol "https" | Where-Object { $_.certificateHash -eq $OldCertThumbprint }
  ```
- Scriptet kører med de samme rettigheder som Task Scheduler-opgaven (typisk SYSTEM).
