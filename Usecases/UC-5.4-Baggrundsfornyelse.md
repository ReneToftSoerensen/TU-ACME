# UC-5.4: Kør lydløs baggrundsfornyelse med fejlopsamling

**Kategori:** Automatisering  
**Prioritet:** Høj

## Mål
Det script, der kører i Task Scheduler, skal forny certifikater og sende e-mail til administratoren, hvis det fejler.

## Aktører
- Windows Task Scheduler (automatisk trigger)
- Systemadministrator (Admin) — modtager e-mail ved fejl

## Prækonditioner
- Scheduled Task er oprettet (UC-5.1).
- SMTP-indstillinger er konfigureret (UC-5.2).
- Mindst ét certifikat administreres af Posh-ACME.

## Hovedforløb
1. Scheduled Task trigger det headless script `Invoke-RenewalBackground.ps1` på det konfigurerede tidspunkt.
2. Scriptet indlæser Posh-ACME-modulet.
3. Scriptet kalder `Submit-Renewal` inde i en `try/catch`-blok.
4. Posh-ACME fornyer alle certifikater, der udløber inden for 30 dage.
5. Hvis fornyelsen lykkes: Scriptet logger succes i Windows Event Log og afslutter lydløst.

## Fejlhåndtering (alternativt forløb ved fejl)
6. Hvis en undtagelse kastes, eller Posh-ACME rapporterer fejlstatus:
   a. Scriptet indlæser de krypterede SMTP-indstillinger (UC-5.2/UC-3.3).
   b. Scriptet genererer en fejlrapport:
      ```
      Tidsstempel:  2026-05-18 03:01:55
      Domæne:       eksempel.dk
      Fejlbesked:   [Posh-ACME fejlbesked her]
      Logfil:       C:\...\posh-acme.log
      ```
   c. Scriptet sender fejl-mailen til den konfigurerede modtager.
   d. Scriptet logger en fejl i Windows Event Log (kilde: `Posh-ACME-TUI`).
7. Post-renewal scriptet til IIS-opdatering (UC-8.4) trigges automatisk af Posh-ACME.

## Postkonditioner
- Certifikater er fornyet (ved succes).
- Administrator er adviseret pr. e-mail (ved fejl).
- Hændelse er logget i Windows Event Log.

## Tekniske noter
- PowerShell-kommando: `Submit-Renewal`
- Windows Event Log: `New-EventLog -Source "Posh-ACME-TUI" -LogName Application`
- Scriptet køres med `-NonInteractive -WindowStyle Hidden` for headless-drift.
