# UC-3.5: ACME-DNS Support

**Kategori:** DNS-Plugins og Credentials  
**Prioritet:** Høj  
**Afhænger af:** UC-3.1 (Vis DNS-Plugins), UC-3.4 (DNS-01 Challenge-konfiguration)

---

## Mål

Understøtte [acme-dns](https://github.com/joohoi/acme-dns) som DNS-01 challenge-metode.  
ACME-DNS er en minimal dedikeret DNS-server med REST API der udelukkende håndterer ACME TXT-records — uden at kræve adgang til hele DNS-zonen.

---

## Baggrund: Hvad er ACME-DNS?

```
Traditionel DNS-01:
  Certifikat-klient → direkte adgang til DNS-provider API

ACME-DNS:
  Certifikat-klient → ACME-DNS server (REST API)
                           ↓
             _acme-challenge.<dit-domæne>
             CNAME → <subdomain>.acme-dns-server.dk

Fordele:
  ✓ Begrænset DNS-adgang — API-nøgler giver kun adgang til ACME-subdomænet
  ✓ Virker med DNS-providers uden API (kun CNAME-record kræves manuelt én gang)
  ✓ Wildcard-certifikater uden fuld DNS-API adgang
  ✓ Velegnet til produktionsmiljøer med strenge sikkerhedskrav
```

---

## Aktører

- Systemadministrator

---

## Prækonditioner

- ACME-DNS server er tilgængelig (enten selvhostet eller offentlig, f.eks. `https://auth.acme-dns.io`)
- Posh-ACME er installeret med AcmeDns-plugin

---

## Opsætningsforløb (første gang)

### Trin 1: Vælg ACME-DNS plugin

I plugin-listen vises `AcmeDns` som en valgmulighed. Når det vælges, starter TUI'en en guidet opsætning i stedet for den generiske plugin-args-dialog.

### Trin 2: Angiv ACME-DNS server

```
  === ACME-DNS Opsætning ===

  ACME-DNS server URL:
  Eksempler:
    https://auth.acme-dns.io       (offentlig testserver)
    https://acmedns.eksempel.dk    (selvhostet)

  ➤ Server URL: _
```

### Trin 3: Registrér ny konto (eller indlæs eksisterende)

```
  Har du allerede en ACME-DNS konto til dette domæne? (J/N)

  J → Angiv eksisterende konto-JSON
  N → Registrér ny konto automatisk
```

**Ny registrering:**

```
  Registrerer konto på auth.acme-dns.io...

  Konto oprettet!
  ┌─────────────────────────────────────────────────────┐
  │ Username:   a0b1c2d3-xxxx-xxxx-xxxx-xxxxxxxxxxxx   │
  │ Password:   xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx │
  │ Subdomain:  a0b1c2d3-xxxx-xxxx-xxxx-xxxxxxxxxxxx   │
  │ FullDomain: a0b1c2d3-xxxx.auth.acme-dns.io         │
  └─────────────────────────────────────────────────────┘
```

### Trin 4: CNAME-instruktion

TUI'en viser den CNAME-record der skal oprettes manuelt i DNS-zonen (gøres kun én gang):

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │  HANDLING PÅKRÆVET — Opret følgende CNAME-record hos din DNS-       │
  │  provider FØR du fortsætter:                                        │
  │                                                                     │
  │  Navn:   _acme-challenge.eksempel.dk                                │
  │  Type:   CNAME                                                      │
  │  Værdi:  a0b1c2d3-xxxx.auth.acme-dns.io.                           │
  │  TTL:    300 (eller lavest muligt)                                  │
  │                                                                     │
  │  Denne record oprettes KUN ÉN GANG og er permanent.                 │
  └─────────────────────────────────────────────────────────────────────┘

  Tryk [Enter] når CNAME-recorden er oprettet og propageret...
```

### Trin 5: Gem credentials

Konto-JSON gemmes krypteret:

```
  $env:ProgramData\TU-ACME\acmedns-<domæne>.json  ← DPAPI-krypteret via Export-Clixml
```

Alternativt gemmes credentials i Posh-ACME's egen `PluginArgs`-mekanisme (UC-3.3).

---

## Fornyelsesforløb (efterfølgende kørsler)

Ved automatisk fornyelse (UC-5.4) genbruges de gemte credentials uden brugerinteraktion:

```powershell
$pArgs = @{
    ACMEDnsServer      = 'https://auth.acme-dns.io'
    ACMEDnsAccountJson = $encryptedJsonPath   # sti til krypteret fil
}
New-PACertificate -Domain 'eksempel.dk' -Plugin AcmeDns -PluginArgs $pArgs
```

---

## Alternative forløb

### ACME-DNS server ikke tilgængelig

```
  [FEJL] Kan ikke forbinde til ACME-DNS server:
  https://auth.acme-dns.io — Connection refused

  Kontrollér at serveren er tilgængelig og URL er korrekt.
  Prøv igen med [Enter] eller afbryd med [ESC].
```

### Eksisterende konto-JSON indlæsning

Brugeren kan angive stien til en eksisterende konto-JSON (f.eks. genereret uden for TUI'en):

```
  ➤ Sti til konto-JSON: C:\PoshACME\acmedns-account.json
  Indlæser... OK
  Username:  a0b1c2d3-xxxx...
  Subdomain: a0b1c2d3-xxxx...
```

### SAN / wildcard med samme ACME-DNS konto

Samme ACME-DNS konto kan bruges til wildcard og base-domæne:

```
  Domæner der deles med denne ACME-DNS konto:
    eksempel.dk
    *.eksempel.dk

  → Begge peger på samme CNAME: _acme-challenge.eksempel.dk
```

---

## Tekniske noter

### Posh-ACME AcmeDns plugin-parametre

| Parameter | Type | Beskrivelse |
|---|---|---|
| `ACMEDnsServer` | String | URL til ACME-DNS server |
| `ACMEDnsAccountJson` | String | Sti til JSON-fil med credentials |

### Konto-JSON struktur (fra acme-dns server)

```json
{
  "username": "a0b1c2d3-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subdomain": "a0b1c2d3-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "fulldomain": "a0b1c2d3-xxxx.auth.acme-dns.io",
  "allowfrom": []
}
```

### Registrering via REST API

```powershell
# Registrer ny ACME-DNS konto
$response = Invoke-RestMethod -Uri "$server/register" -Method Post `
    -ContentType 'application/json' -Body '{}'
# Returnerer: username, password, subdomain, fulldomain

# Gem JSON til krypteret fil
$response | ConvertTo-Json | Set-Content -Path $jsonPath -Encoding UTF8
```

### Gemme-sti konvention

```
$env:ProgramData\TU-ACME\acmedns-accounts\<sanitized-domain>.json
```

Filnavnet saniteres: `eksempel.dk` → `eksempel_dk.json`

---

## Acceptkriterier

- [ ] `AcmeDns` vises i plugin-listen og udløser guidet ACME-DNS opsætning
- [ ] Ny konto kan registreres automatisk via REST API med visuel feedback
- [ ] Eksisterende konto-JSON kan indlæses fra fil
- [ ] CNAME-instruktion vises klart med korrekte værdier inden brugeren fortsætter
- [ ] Credentials gemmes krypteret under `$env:ProgramData\TU-ACME\acmedns-accounts\`
- [ ] Ved fornyelse genbruges gemte credentials uden interaktion
- [ ] Wildcard-domæner (`*.eksempel.dk`) understøttes med samme ACME-DNS konto
