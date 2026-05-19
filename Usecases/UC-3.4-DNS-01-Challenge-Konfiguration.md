# UC-3.4: DNS-01 Challenge-konfiguration

**Kategori:** DNS-Plugins og Credentials  
**Prioritet:** Høj  
**Afhænger af:** UC-3.1 (Vis DNS-Plugins), UC-3.2 (Maskeret Credentials), UC-2.2 (Bestil Certifikat)

---

## Mål

Give administratoren kontrol over DNS-01 challenge-parametre: propagationsvente-tid (`DnsSleep`), valideringstimeout og valg om DNS TXT-records skal slettes efter vellykket challenge (persistent mode).

---

## Aktører

- Systemadministrator

---

## Prækonditioner

- DNS-plugin er valgt (UC-3.1) og credentials er indlæst (UC-3.2)
- Posh-ACME er installeret og konfigureret med aktiv ACME-konto

---

## Baggrund: DNS-01 challenge-forløbet

```
Bruger bestiller certifikat
    ↓
Posh-ACME opretter DNS TXT-record:
    _acme-challenge.<domæne> = "<token>"
    ↓
Venter DnsSleep sekunder (standard: 120 sek)
    — DNS propagation —
    ↓
ACME-server validerer TXT-record
    ↓
Certifikat udstedes
    ↓
TXT-record slettes (med mindre persistent mode er aktivt)
```

---

## Hovedforløb

1. Efter plugin og credentials er valgt (UC-3.1/3.2) vises DNS-01 challenge-konfiguration:

```
  === DNS-01 Challenge-indstillinger ===

  DNS-propagation ventetid (DnsSleep):
  Standard: 120 sekunder
  ➤ Angiv sekunder (blank = standard): _

  Valideringstimeout:
  Standard: 60 sekunder
  ➤ Angiv sekunder (blank = standard): _

  Persistent DNS-records:
  [ ] Behold TXT-records efter validering (persistent mode)

  [Enter] Fortsæt  [ESC] Afbryd
```

2. Brugeren angiver DnsSleep (blank = behold standard 120 sek).
3. Brugeren angiver valideringstimeout (blank = behold standard 60 sek).
4. Brugeren vælger om DNS TXT-records skal slettes efter validering:
   - **Standard (ikke persistent):** Records slettes automatisk af plugin'et efter validering
   - **Persistent mode:** Records efterlades i DNS — nyttigt ved langsomme DNS-providers eller ved genvalidering uden ny credential-opsætning

5. Opsummering opdateres med DNS-01-parametre:
```
  === Opsummering ===

  Domæne:          eksempel.dk
  Plugin:          Cloudflare
  Challenge:       DNS-01
  DNS-sleep:       120 sek
  Timeout:         60 sek
  Persistent DNS:  Nej

  [J] Bekræft  [N] Afbryd
```

---

## Postkonditioner

- `New-PACertificate` kaldes med `-DnsSleep` og `-ValidationTimeout`
- Spinner viser propagationsfasen:
  ```
  [ / ] Opretter DNS TXT-record...
  [ - ] Venter på DNS-propagation (120 sek)...
  [ \ ] Validerer challenge med ACME-server...
  [ | ] Modtager certifikat...
  ```

---

## Alternative forløb

### DNS-propagation fejler (timeout)

```
  [FEJL] DNS-validering mislykkedes:
  ACME-serveren kunne ikke bekræfte TXT-recorden inden timeout.

  Mulige årsager:
  - DNS-propagation er ikke fuldendt endnu
  - DnsSleep er for lav for din DNS-provider

  Anbefalinger:
  ✓ Forøg DnsSleep til 300+ sekunder og prøv igen
  ✓ Kontrollér at TXT-recorden er oprettet korrekt hos din DNS-provider
  ✓ Brug Staging til test: [F3] Staging-toggle
```

### Persistent mode aktiveret

Når `Persistent mode` er valgt, kalder Posh-ACME **ikke** plugin'ets `Remove-DnsTxt`-funktion. TXT-recorden forbliver i DNS:

```powershell
# Persistent mode — brug -NoSavePfxPass er ikke relevant her,
# Posh-ACME haandterer cleanup via plugin-aftalen
New-PACertificate -Domain $domains -Plugin $plugin -PluginArgs $pArgs `
    -DnsSleep $dnsSleep -ValidationTimeout $timeout
# Records efterlades naar plugin ikke modtager cleanup-kald
```

> **Bemærk:** Persistent DNS-records kan udgøre en minimal sikkerhedsrisiko da ACME-tokens er synlige i DNS. Records bør fjernes manuelt når de ikke længere er nødvendige.

### Plugin understøtter ikke cleanup

Visse plugins (f.eks. `Manual`) understøtter aldrig automatisk cleanup — DNS er altid persistent i disse tilfælde. TUI viser:

```
  Bemærk: Pluginet 'Manual' kræver manuel oprettelse og sletning
  af DNS TXT-records. Records fjernes ikke automatisk.
```

---

## Tekniske noter

### Posh-ACME parametre

| Parameter | Standard | Beskrivelse |
|---|---|---|
| `-DnsSleep` | 120 | Sekunder at vente efter TXT-record er oprettet |
| `-ValidationTimeout` | 60 | Sekunder ACME-serveren har til at validere |
| `-NoSkipManualEdit` | `$false` | Pause til manuel DNS-redigering (Manual plugin) |

```powershell
New-PACertificate -Domain $domains `
    -Plugin $plugin `
    -PluginArgs $pArgs `
    -DnsSleep $dnsSleep `
    -ValidationTimeout $valTimeout `
    -AcceptTOS
```

### Gem DNS-indstillinger i config.json

DNS-01-indstillinger gemmes i `$env:ProgramData\TU-ACME\config.json` under en ny sektion:

```json
{
  "DNS": {
    "DefaultDnsSleep": 120,
    "DefaultValidationTimeout": 60,
    "PersistentRecords": false
  }
}
```

Dette sikrer at indstillingerne genbruges ved fornyelse via Scheduled Task (UC-5.4).

---

## Acceptkriterier

- [ ] DnsSleep og ValidationTimeout kan konfigureres i UI'en med blankt = standard
- [ ] Persistent mode kan aktiveres med eksplicit advarsel om sikkerhedsimplikationer
- [ ] Spinner viser klar status under hvert trin af DNS-01-forløbet
- [ ] Indstillingerne gemmes i config.json og genbruges ved automatisk fornyelse
- [ ] Fejlbeskeder ved DNS-timeout indeholder konkrete løsningsforslag
