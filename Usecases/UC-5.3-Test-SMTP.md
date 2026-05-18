# UC-5.3: Test SMTP-forbindelse og send test-mail fra TUI

**Kategori:** Automatisering  
**Prioritet:** Medium

## Mål
Give administratoren mulighed for med det samme at bekræfte, at SMTP-indstillingerne fungerer korrekt.

## Aktører
- Systemadministrator (Admin)

## Prækonditioner
- SMTP-indstillinger er konfigureret og gemt (UC-5.2).

## Hovedforløb
1. Efter at have gemt SMTP-indstillingerne (UC-5.2), vælger brugeren "Send Test-mail".
2. TUI'en viser: `Sender test-mail til admin@eksempel.dk...`
3. Systemet indlæser de krypterede SMTP-indstillinger.
4. Systemet forsøger at sende en test-e-mail med emnet:  
   `[Posh-ACME TUI] Test-mail - SMTP konfigurationen virker`
5. Hvis afsendelse lykkes:
   ```
   [OK] Test-mail sendt med succes til admin@eksempel.dk
   ```
6. Brugeren kan herefter bekræfte modtagelsen i sin indbakke.

## Postkonditioner
- SMTP-konfigurationen er verificeret og klar til brug.

## Alternative forløb
- **4a:** Forbindelsesfejl → Rød fejlbesked med den præcise .NET/SMTP-fejlbesked, f.eks.:  
  `[FEJL] System.Net.Mail.SmtpException: Unable to connect to the remote server`
- **4b:** Autentificeringsfejl → Besked om forkert brugernavn/adgangskode.

## Tekniske noter
- Test-mail indeholder tidsstempel og TUI-version for sporbarhed.
- Bruger samme afsendelseslogik som baggrundsscriptet (UC-5.4).
