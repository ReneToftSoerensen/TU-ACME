# TU-ACME

En interaktiv, tekstbaseret terminal-brugerflade (TUI) til PowerShell-modulet [Posh-ACME](https://github.com/rmbolger/Posh-ACME). Administrér Let's Encrypt-certifikater, DNS-validering, automatisk fornyelse og IIS-integration — alt sammen direkte fra terminalen.

---

## Funktioner

| Kategori | Funktion |
|---|---|
| **Kontostyring** | Opret, skift og administrér ACME-konti (Production/Staging) |
| **Certifikater** | Bestil certifikater med DNS-validering og realtids-statusindikator |
| **DNS-Plugins** | Understøtter alle Posh-ACME DNS-plugins (Azure, Cloudflare, Route53 m.fl.) |
| **Dashboard** | Farvekodet overblik over certifikatstatus og udløbsdatoer |
| **Automatisering** | Windows Scheduled Task til natlig fornyelse med e-mail-advisering ved fejl |
| **Eksport/Import** | Eksportér til PFX, PEM/CRT/KEY, eller importér direkte til Windows Certificate Store |
| **IIS Integration** | Scan, kobl og opdatér IIS HTTPS-bindings automatisk ved fornyelse |
| **Fejlsøgning** | Læs og eksportér Posh-ACME logfiler direkte i TUI'en |

---

## Krav

- **OS:** Windows (Windows 10/11, Windows Server 2016 og nyere, inkl. Server Core)
- **PowerShell:** 5.0 eller nyere
- **Posh-ACME:** Installeret via `Install-Module Posh-ACME`
- **Administratorrettigheder:** Kræves til IIS-administration og oprettelse af Scheduled Tasks
- **IIS-funktioner** *(kun til UC-8.x)*: Internet Information Services med modulet `WebAdministration`

---

## Installation

```powershell
# 1. Installér Posh-ACME hvis ikke allerede installeret
Install-Module -Name Posh-ACME -Scope AllUsers

# 2. Klon eller download dette repository
git clone https://github.com/renetoftsoerensen/tu-acme.git
cd tu-acme

# 3. Start TUI'en (kør som Administrator for fuld adgang)
.\Scripts\Start-TUACME.ps1
```

---

## Brug

Start TUI'en i en PowerShell-session. For fuld funktionalitet (IIS, Scheduled Tasks) skal PowerShell køres som Administrator.

```
TU-ACME v0.0.2
==========================================
Aktiv konto: admin@eksempel.dk | Let's Encrypt Production

  1. Kontostyring
  2. Bestil nyt certifikat
  3. Certifikat-dashboard
  4. Automatisering
  5. Eksport / Import
  6. IIS Integration
  7. Fejlsoegning / Logs
  Q. Afslut

[F3] Skift til Staging   [F1] Hjælp
```

Naviger med **piletasterne**, vælg med **Enter**, og gå tilbage med **ESC** eller **Q**.

---

## Use Cases

Alle funktioner er dokumenteret som atomare use cases i mappen [`Usecases/`](./Usecases/):

| ID | Beskrivelse | Prioritet |
|---|---|---|
| UC-0.1 | Kontrol af administrator-rettigheder ved opstart | Høj |
| UC-1.1 | Vis liste over eksisterende ACME-konti | Høj |
| UC-1.2 | Opret ny ACME-konto | Høj |
| UC-1.3 | Skift aktiv ACME-konto | Høj |
| UC-1.4 | Hurtig skift til Staging/Test-miljø | Høj |
| UC-2.1 | Indtast domænenavn og alternative navne (SAN) | Høj |
| UC-2.2 | Bestil certifikat og vis realtids statusindikator | Høj |
| UC-3.1 | Vis understøttede DNS-plugins i menu | Høj |
| UC-3.2 | Indtast og maskér API-credentials i prompt | Høj |
| UC-3.3 | Gem API-credentials krypteret på disken | Høj |
| UC-4.1 | Vis interaktiv tabel over certifikater (Farvekodet) | Høj |
| UC-4.2 | Sortering og filtrering af certifikatlisten | Medium |
| UC-4.3 | Vis detaljerede oplysninger om et valgt certifikat | Medium |
| UC-5.1 | Opret Windows Scheduled Task til natlig kørsel | Høj |
| UC-5.2 | Konfigurer og gem SMTP-indstillinger til e-mail | Høj |
| UC-5.3 | Test SMTP-forbindelse og send test-mail fra TUI | Medium |
| UC-5.4 | Kør lydløs baggrundsfornyelse med fejlopsamling | Høj |
| UC-6.1 | Eksportér certifikat til PFX-fil | Medium |
| UC-6.2 | Eksportér certifikat til PEM/Key/Cert filer | Medium |
| UC-6.3 | Importér certifikat direkte til Windows Certificate Store | Høj |
| UC-7.1 | Gennemse seneste logfiler direkte i TUI (Pager) | Medium |
| UC-7.2 | Eksporter logfiler til ekstern fil | Lav |
| UC-8.1 | Scan lokale IIS-sites og HTTPS-bindings | Høj |
| UC-8.2 | Kobl certifikat til IIS-endpoints manuelt via TUI | Høj |
| UC-8.3 | Registrer Post-Renewal Plugin (IIS Update) i Posh-ACME | Høj |
| UC-8.4 | Automatisk IIS-opdatering via Post-Renewal script | Høj |

---

## Sikkerhed

- API-nøgler og adgangskoder gemmes **aldrig i klartekst**. Al hemmelig information krypteres med Windows DPAPI via PowerShells `Export-Clixml`.
- TUI'en detekterer automatisk om den kører med forhøjede rettigheder og deaktiverer administrative funktioner hvis ikke (UC-0.1).
- Krypterede data er bundet til den bruger og maskine, der gemte dem — og kan ikke læses af andre brugere eller på andre maskiner.

---

## Automatisk fornyelse

Når automatisering er konfigureret (UC-5.1), kører fornyelsen natligt uden brugerinteraktion:

```
Task Scheduler (03:00)
  └── Invoke-RenewalBackground.ps1
        └── Submit-Renewal (Posh-ACME)
              ├── [Succes] → Log til Windows Event Log
              ├── [Fejl]   → Send fejl-email til administrator (UC-5.4)
              └── [Fornyelse] → Trigger Posh-ACME-IIS-Plugin.ps1 (UC-8.4)
                                  └── Opdatér IIS-bindings automatisk
```

---

## Licens

Se [LICENSE](./LICENSE) for licensbetingelser.
