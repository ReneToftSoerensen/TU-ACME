# CLAUDE.md — Posh-ACME TUI

## Projektbeskrivelse
En interaktiv tekstbaseret terminal-brugerflade (TUI) til PowerShell-modulet Posh-ACME. Projektet giver systemadministratorer et fuldt menustyret interface til at administrere ACME/Let's Encrypt-certifikater på Windows-servere, inklusiv IIS-integration og automatisk fornyelse.

## Platform og minimumskrav
- **OS:** Windows (klient og server, inkl. Windows Server Core)
- **PowerShell:** 5.0 minimum (matcher Posh-ACME's eget minimumskrav)
- **Kørselsmiljø:** Direkte i eksisterende konsol-session — ingen grafiske afhængigheder
- **Remoting:** Understøtter PowerShell Remoting (WinRM/SSH) på headless systemer

## Mappestruktur
```
TU-ACME/
├── CLAUDE.md               # Denne fil
├── README.md               # Projektdokumentation
├── Usecases/               # Granulerede use case-dokumenter (UC-X.Y)
│   ├── UC-0.1-*.md         # System
│   ├── UC-1.x-*.md         # Kontostyring
│   ├── UC-2.x-*.md         # Certifikatbestilling
│   ├── UC-3.x-*.md         # DNS-Plugins og Credentials
│   ├── UC-4.x-*.md         # Dashboard
│   ├── UC-5.x-*.md         # Automatisering
│   ├── UC-6.x-*.md         # Eksport og Import
│   ├── UC-7.x-*.md         # Fejlsøgning
│   └── UC-8.x-*.md         # IIS Integration
└── Scripts/                # PowerShell-scripts (implementering)
    ├── Start-PoshACMETUI.ps1
    └── Posh-ACME-IIS-Plugin.ps1
```

## Arkitekturprincipper
- **Rent TUI-mønster:** Al interaktion sker via tekstbaserede menuer, tabelvisninger og prompter i terminalen. Ingen GUI-afhængigheder.
- **Wrapper-arkitektur:** TUI'en kalder Posh-ACME-kommandoer direkte. Ingen forretningslogik duplikeres — Posh-ACME er kilden til sandhed.
- **Sikkerhed first:** Følsomme data (API-nøgler, SMTP-adgangskoder) gemmes aldrig i klartekst. Brug altid `SecureString` og DPAPI (`Export-Clixml`).
- **Headless-kompatibilitet:** Baggrundsscripts kører med `-NonInteractive -WindowStyle Hidden` og bruger Windows Event Log til output.

## Brugerroller
| Rolle | Adgang |
|---|---|
| **Systemadministrator (Admin)** | Fuld adgang — konfigurering, bestilling, automatisering, IIS |
| **Overvåger/Tekniker (ReadOnly)** | Kun dashboard (UC-4.x) og logvisning (UC-7.1) |

## Nøgle-use cases (prioriteret)
Alle use cases er dokumenteret i mappen `Usecases/`. Høj-prioriterede cases:
- **UC-0.1** — Rettighedstjek ved opstart (fundament for alle admin-funktioner)
- **UC-2.2** — Certifikatbestilling med realtids-spinner
- **UC-4.1** — Farvekodet certifikat-dashboard
- **UC-5.1 + UC-5.4** — Automatisk fornyelse via Task Scheduler
- **UC-8.3 + UC-8.4** — Automatisk IIS-opdatering via post-renewal plugin

## Vigtige PowerShell-kommandoer
```powershell
# Kontostyring
Get-PAAccount -List
New-PACAccount -AcceptTOS -Contact "mail@eks.dk"
Set-PAAccount -ID "<id>"

# Certifikater
Get-PACertificate -List
New-PACertificate -Domain "eks.dk" -Plugin Cloudflare -PluginArgs $args
Submit-Renewal

# IIS
Import-Module WebAdministration
Get-WebBinding -Protocol "https"
Set-WebBinding -Name "<site>" -PropertyName "certificateHash" -Value $thumbprint

# Automatisering
Register-ScheduledTask -TaskName "Posh-ACME-AutoRenewal" ...
Set-PAConfig -PostScript "<sti-til-plugin>"
```

## Sikkerhedsretningslinjer
- Kald altid `Read-Host -AsSecureString` til adgangskoder og API-nøgler — aldrig `Read-Host` uden.
- Gem kun krypteret: `Export-Clixml` (DPAPI-baseret, maskin/bruger-bundet).
- Tjek administrator-rettigheder ved opstart (UC-0.1) — deaktivér admin-menuer hvis ikke forhøjet.
- Log til Windows Event Log i baggrundsscripts — aldrig til filer i klartekst der indeholder credentials.

## Udviklings-workflow
1. Alle use cases er atomare og kan implementeres uafhængigt.
2. Brug `claude/posh-acme-tui-specs-9Sbhg` som udviklingsbranch.
3. Commit hyppigt med beskrivende commit-beskeder på dansk eller engelsk.
4. Test TUI-input/output manuelt i en PowerShell 5.0-session inden push.
