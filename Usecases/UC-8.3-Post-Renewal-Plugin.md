# UC-8.3: Registrer Post-Renewal Plugin (IIS Update) i Posh-ACME

**Kategori:** IIS Integration  
**Prioritet:** Høj

## Mål
At konfigurere Posh-ACME til automatisk at køre IIS-opdateringsscriptet, hver gang et certifikat fornyes i baggrunden.

## Aktører
- Systemadministrator (Admin)

## Prækonditioner
- TUI kører med administratorrettigheder (UC-0.1).
- Posh-ACME er installeret.
- Post-renewal scriptet `Posh-ACME-IIS-Plugin.ps1` er inkluderet i TUI-installationen.

## Hovedforløb
1. Brugeren vælger "IIS-integration" → "Opsæt Auto-opdatering af bindings".
2. TUI'en identificerer den fulde sti til det medfølgende plugin-script:  
   `C:\Program Files\TU-ACME\Scripts\Posh-ACME-IIS-Plugin.ps1`
3. TUI'en viser stien og beder om bekræftelse:  
   `Registrer IIS-plugin: [sti]? [J/N]`
4. Brugeren bekræfter med **J**.
5. Appen kalder:
   ```powershell
   Set-PAConfig -PostScript "C:\...\Posh-ACME-IIS-Plugin.ps1"
   ```
6. Succes-besked: `IIS Auto-opdatering aktiveret. Post-renewal plugin er registreret.`

## Postkonditioner
- Posh-ACME er konfigureret til at kalde IIS-opdateringsscriptet efter hver succesfuld fornyelse.
- Automatisk IIS-opdatering (UC-8.4) er nu aktiv.

## Alternative forløb
- **2a:** Plugin-scriptet ikke fundet → Fejlbesked med vejledning til manuel placering af scriptet.
- **4a:** Brugeren svarer N → Afbrydes uden ændringer.

## Tekniske noter
- PowerShell-kommando: `Set-PAConfig -PostScript "<sti>"`
- Scriptet modtager certifikatoplysninger som parametre fra Posh-ACME ved fornyelse.
- Eksisterende post-script konfiguration vises, inden der overskrives.
