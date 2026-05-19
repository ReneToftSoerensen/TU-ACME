# UC-3.2: Indtast og maskér API-credentials i prompt

**Kategori:** DNS-Plugins og Credentials  
**Prioritet:** Høj

## Mål
Sikre, at adgangskoder og API-nøgler ikke kan aflæses på skærmen under indtastning.

## Aktører
- Systemadministrator (Admin)

## Prækonditioner
- Et DNS-plugin er valgt (UC-3.1).
- TUI'en kender de påkrævede parametre for det valgte plugin.

## Hovedforløb
1. TUI'en viser en liste over de påkrævede parametre for det valgte plugin, f.eks. for Cloudflare:
   ```
   Cloudflare konfiguration:
   API Token (hemmelig): _
   ```
2. For hvert parameter markeret som hemmeligt:
   - Når brugeren taster, vises kun `*` for hvert tegn (eller inputtet skjules helt).
   - Backspace fungerer korrekt og sletter det seneste skjulte tegn.
3. For ikke-hemmelige parametre (f.eks. zone-ID) vises inputtet normalt.
4. Brugeren bekræfter alle parametre.

## Postkonditioner
- API-credentials er opsamlet som `SecureString` i hukommelsen.
- Credentials sendes videre til UC-3.3 til krypteret lagring.

## Alternative forløb
- **2a:** Brugeren trykker ESC → Afbryder uden at gemme.

## Tekniske noter
- Brug `Read-Host -AsSecureString` til maskeret input i PowerShell.
- Plugin-parametre og deres type (hemmeligt/offentligt) er dokumenteret i Posh-ACMEs plugin-hjælpefiler.
