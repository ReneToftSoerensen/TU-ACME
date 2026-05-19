# UC-1.2: Opret ny ACME-konto

**Kategori:** Kontostyring  
**Prioritet:** Høj

## Mål
At registrere en ny konto hos en ACME-udbyder (Let's Encrypt, ZeroSSL eller custom).

## Aktører
- Systemadministrator (Admin)

## Prækonditioner
- Brugeren kører TUI som Administrator.
- Internetadgang er tilgængelig til ACME-udbyderens endpoint.

## Hovedforløb
1. Brugeren vælger "Opret ny konto" i Kontostyring-menuen.
2. TUI'en prompter for en e-mailadresse (kontaktadresse til ACME-udbyderen).
3. TUI'en viser en liste over kendte ACME-servere:
   - Let's Encrypt (Production)
   - Let's Encrypt (Staging)
   - ZeroSSL
   - Custom (brugerdefineret URL)
4. Brugeren vælger server.
5. TUI'en viser Terms of Service og prompter: `Accepterer du vilkårene? [J/N]`.
6. Brugeren bekræfter med `J`.
7. Appen kalder `New-PACAccount` og opretter kontoen.
8. Succes-besked vises med den nye kontos ID og e-mailadresse.

## Postkonditioner
- En ny ACME-konto er registreret og sat som aktiv konto.

## Alternative forløb
- **4a:** Custom server valgt → Brugeren promptes for server-URL.
- **6a:** Brugeren svarer `N` → Afbrydes, ingen konto oprettes.
- **7a:** Netværksfejl → Fejlbesked vises med præcis fejlmeddelelse.

## Tekniske noter
- PowerShell-kommando: `New-PACAccount -AcceptTOS -Contact "mail@eksempel.dk"`
- For custom server: `New-PAServer -DirectoryUrl "https://custom.acme/dir"`
