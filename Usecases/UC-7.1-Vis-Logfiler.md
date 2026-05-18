# UC-7.1: Gennemse seneste logfiler direkte i TUI (Pager)

**Kategori:** Fejlsøgning  
**Prioritet:** Medium

## Mål
Læse Posh-ACMEs logfiler uden at skulle forlade TUI-applikationen eller åbne Notepad.

## Aktører
- Systemadministrator (Admin)
- Overvåger/Tekniker (ReadOnly)

## Prækonditioner
- Posh-ACME er installeret og har logfiler.

## Hovedforløb
1. Brugeren vælger "Vis Logs" i menuen.
2. TUI'en indlæser den seneste logfil fra Posh-ACME logmappen.
3. Logfilens indhold vises i et rullebart tekstfelt i terminalen.
4. Navigation i loggen:
   - **↑ / ↓** Pilene ruller én linje ad gangen
   - **PageUp / PageDown** Ruller én side ad gangen
   - **Home / End** Springer til toppen / bunden
5. Brugeren trykker **ESC** eller **Q** for at vende tilbage til menuen.

## Postkonditioner
- Brugeren har kunnet læse logfilen og er returneret til menuen.

## Alternative forløb
- **2a:** Ingen logfil fundet → Besked: `Ingen logfil fundet i Posh-ACME logmappen.`
- **2b:** Flere logfiler → TUI viser en liste over de seneste logfiler og brugeren vælger hvilken.

## Tekniske noter
- Logfil-sti: Typisk `$env:LOCALAPPDATA\Posh-ACME\*.log` eller Posh-ACMEs konfigurationsmappe.
- Pager implementeres med `[Console]::SetCursorPosition` og manuel scroll-logik.
- Fra logvisningen kan brugeren starte UC-7.2 (eksport).
