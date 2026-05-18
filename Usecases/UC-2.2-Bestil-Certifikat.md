# UC-2.2: Bestil certifikat og vis realtids statusindikator

**Kategori:** Certifikatbestilling  
**Prioritet:** Høj

## Mål
Give visuel feedback til brugeren, mens ACME-udfordringen og certifikatbestillingen afvikles i baggrunden.

## Aktører
- Systemadministrator (Admin)

## Prækonditioner
- Domænenavne er valideret (UC-2.1).
- DNS-plugin og credentials er konfigureret (UC-3.1 / UC-3.2 / UC-3.3).

## Hovedforløb
1. Brugeren bekræfter bestillingen med en opsummeringsvisning.
2. TUI'en kalder `New-PACertificate` med de angivne parametre.
3. TUI'en rydder skærmen og viser en animeret spinner med statusbeskeder:
   ```
   [ / ] Opretter certifikatordre...
   [ - ] Publicerer DNS TXT-record via plugin...
   [ \ ] Venter på DNS-propagering...
   [ | ] Validerer ACME-udfordring...
   [ / ] Henter certifikat...
   ```
4. Ved **succes**: Grøn succes-besked vises:
   ```
   [OK] Certifikat udstedt!
   Domæne:      eksempel.dk
   Udloeber:    2026-08-18
   Thumbprint:  A1B2C3D4...
   ```
5. TUI'en returnerer til dashboard (UC-4.1) med det nye certifikat i listen.

## Postkonditioner
- Certifikatet er udstedt og gemt af Posh-ACME.

## Alternative forløb
- **3a:** DNS-propagering tager for lang tid → TUI viser ventetid og timeout-countdown.
- **4a (Fejl):** Rød fejlbesked vises med den præcise fejlmeddelelse fra Posh-ACME/ACME-serveren.
- **4b:** Rate-limit ramt → TUI'en anbefaler at skifte til Staging (UC-1.4).

## Tekniske noter
- PowerShell-kommando: `New-PACertificate -Domain "eksempel.dk","www.eksempel.dk" -Plugin Cloudflare -PluginArgs $pArgs`
- Spinner implementeres med `Write-Host -NoNewline` og `[Console]::SetCursorPosition`.
