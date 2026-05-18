# UC-7.2: Eksporter logfiler til ekstern fil

**Kategori:** Fejlsøgning  
**Prioritet:** Lav

## Mål
Nemt at samle logfiler sammen til at sende til support eller til videre fejlfinding.

## Aktører
- Systemadministrator (Admin)
- Overvåger/Tekniker (ReadOnly)

## Prækonditioner
- Logvisning er aktiv (UC-7.1).
- Den ønskede logfil er indlæst.

## Hovedforløb
1. Mens logvisningen er aktiv (UC-7.1), trykker brugeren **E** for eksport.
2. TUI'en foreslår en standard destinationssti:  
   `Gem logfil som: C:\Users\<bruger>\Desktop\posh-acme-log-2026-05-18.txt`
3. Brugeren kan acceptere standarden med Enter eller skrive en anden sti.
4. TUI'en gemmer en kopi af den aktuelle logfil på den angivne sti.
5. Succes-besked vises:  
   `[OK] Logfil gemt: C:\Users\admin\Desktop\posh-acme-log-2026-05-18.txt`

## Postkonditioner
- En kopi af logfilen er gemt på den angivne sti, klar til at sendes til support.

## Alternative forløb
- **3a:** Sti er ugyldig eller skriverettigheder mangler → Fejlbesked.
- **4a:** Fil eksisterer allerede → Brugeren spørges om overskrivning.

## Tekniske noter
- Filnavnet inkluderer automatisk dato for sporbarhed: `posh-acme-log-YYYY-MM-DD.txt`
- Brug `Copy-Item` eller `Get-Content | Set-Content` til kopiering.
