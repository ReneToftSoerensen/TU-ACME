# UC-2.1: Indtast domænenavn og alternative navne (SAN)

**Kategori:** Certifikatbestilling  
**Prioritet:** Høj

## Mål
Opsamle domæneoplysninger til det nye certifikat uden risiko for syntaksfejl.

## Aktører
- Systemadministrator (Admin)

## Prækonditioner
- En aktiv ACME-konto er konfigureret (UC-1.1 / UC-1.2).

## Hovedforløb
1. Brugeren vælger "Bestil nyt certifikat" i hovedmenuen.
2. TUI'en prompter for **Primært domænenavn (Common Name)**:  
   `Primært domæne: _` (f.eks. `eksempel.dk`)
3. TUI'en prompter for **Alternative navne (SAN)** (valgfrit):  
   `Alternative navne (kommasepareret, tryk Enter for at springe over): _`  
   (f.eks. `www.eksempel.dk, mail.eksempel.dk`)
4. Systemet validerer input:
   - Primært domæne må ikke være tomt.
   - Alle domæner valideres mod RFC-kompatibel domæne-syntaks (regex).
   - Eventuelle whitespace-fejl i SAN-listen trimmes automatisk.
5. Ved gyldig input vises en opsummeringsvisning med alle domæner inden bekræftelse.

## Postkonditioner
- Domænenavne er valideret og klar til certifikatbestilling (UC-2.2).

## Alternative forløb
- **4a:** Ugyldigt domæneformat → Rød fejlbesked og brugeren bedes rette inputtet.
- **4b:** Wildcard-domæne (f.eks. `*.eksempel.dk`) → Accepteres, men DNS-validering kræves.

## Tekniske noter
- Domænevalidering regex: `^(\*\.)?([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$`
