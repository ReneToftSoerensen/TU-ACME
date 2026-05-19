# Installation af TU-ACME

## Indholdsfortegnelse

1. [Systemkrav](#1-systemkrav)
2. [Forudsætninger](#2-forudsætninger)
3. [Installation](#3-installation)
4. [Konfiguration af data-mapper](#4-konfiguration-af-data-mapper)
5. [Første opstart](#5-første-opstart)
6. [Valgfri: IIS-integration](#6-valgfri-iis-integration)
7. [Valgfri: Automatisk fornyelse](#7-valgfri-automatisk-fornyelse)
8. [Afinstallation](#8-afinstallation)
9. [Fejlfinding](#9-fejlfinding)

---

## 1. Systemkrav

| Krav | Minimum | Anbefalet |
|---|---|---|
| Operativsystem | Windows Server 2016 / Windows 10 | Windows Server 2019+ / Windows 11 |
| PowerShell | 5.1 | 5.1 (kun) — PS 7.x understøttes ikke |
| Rettigheder | Bruger (dashboard/logs) | Administrator (certifikater, IIS, Tasks) |
| Netværk | Udgående HTTPS (port 443) til ACME-server og DNS-provider API | — |
| Diskplads | < 5 MB | — |

> **Windows Server Core:** Fuldt understøttet. TUI'en bruger udelukkende konsol-I/O.  
> **PowerShell Remoting (WinRM/SSH):** Understøttet — ingen grafiske afhængigheder.

---

## 2. Forudsætninger

### 2.1 Installér Posh-ACME

TU-ACME er en TUI-wrapper til [Posh-ACME](https://github.com/rmbolger/Posh-ACME) og kræver at det er installeret.

```powershell
# Kræver Administrator — installerer for alle brugere (inkl. SYSTEM-kontoen)
Install-Module -Name Posh-ACME -Scope AllUsers -Force
```

Verificér installationen:

```powershell
Get-Module -ListAvailable Posh-ACME
# Forventet output: Version 4.x.x eller nyere
```

### 2.2 PowerShell Execution Policy

Scripts skal have tilladelse til at køre:

```powershell
# Vis nuværende policy
Get-ExecutionPolicy -List

# Sæt policy til RemoteSigned (anbefalet minimum)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

### 2.3 IIS (kun ved IIS-integration)

Hvis IIS-funktionerne (UC-8.x) skal bruges, skal `WebAdministration`-modulet være tilgængeligt:

```powershell
# Kontrollér at WebAdministration er installeret
Get-Module -ListAvailable WebAdministration

# Installér IIS Management Tools hvis det mangler (Windows Server)
Install-WindowsFeature -Name Web-Mgmt-Tools
```

---

## 3. Installation

### Trin 1: Download TU-ACME

**Mulighed A — Git clone (anbefalet):**

```powershell
git clone https://github.com/renetoftsoerensen/tu-acme.git
cd tu-acme
```

**Mulighed B — Download ZIP:**

Download og udpak `tu-acme.zip` til en mappe på serveren.

---

### Trin 2: Kopiér modul til PowerShell-modulsti

```powershell
# Kræver Administrator
$moduleDest = "$env:ProgramFiles\WindowsPowerShell\Modules\TU-ACME"

Copy-Item -Path ".\TU-ACME" -Destination $moduleDest -Recurse -Force

# Verificér at modulet kan findes
Get-Module -ListAvailable TU-ACME
```

Forventet output:

```
ModuleType  Version  Name      ExportedCommands
----------  -------  ----      ----------------
Script      1.0.0    TU-ACME   Start-TUACME
```

---

### Trin 3: Importér og start

```powershell
Import-Module TU-ACME
Start-TUACME
```

> **Tip:** Kør altid PowerShell som Administrator for fuld adgang til alle funktioner.  
> Starter du som almindelig bruger, er dashboard og logvisning tilgængeligt — administrative funktioner (IIS, Tasks) deaktiveres automatisk.

---

## 4. Konfiguration af data-mapper

TU-ACME opretter automatisk disse mapper ved første opstart:

| Sti | Indhold |
|---|---|
| `$env:ProgramData\TU-ACME\` | Rodmappe for konfiguration og credentials |
| `$env:ProgramData\TU-ACME\config.json` | Ikke-hemmelige indstillinger (SMTP, Task, Dashboard, DNS) |
| `$env:ProgramData\TU-ACME\smtp-credentials.xml` | SMTP-credentials (DPAPI-krypteret) |
| `$env:ProgramData\TU-ACME\acmedns-accounts\` | ACME-DNS konto-JSON filer (én pr. domæne) |

Mapperne oprettes med standard Windows-rettigheder — tilgængeligt for alle brugere og `SYSTEM`-kontoen.

### Opret manuelt (valgfrit)

```powershell
New-Item -ItemType Directory -Path "$env:ProgramData\TU-ACME" -Force
```

---

## 5. Første opstart

### 5.1 Start TUI'en

```powershell
# Start som Administrator (anbefalet)
Start-TUACME
```

### 5.2 Opret ACME-konto

Vælg **1. Kontostyring → Opret ny konto** og angiv:

- **E-mail:** Administratorens e-mailadresse (bruges til ekspirationsadvarsler fra Let's Encrypt)
- **Server:** Let's Encrypt Produktion (eller Staging til test)

```
Anbefaling: Test altid på Staging (F3) inden du bestiller produktionscertifikater.
Let's Encrypt har rate limits på produktionsserveren.
```

### 5.3 Registrér Windows Event Log-kilde

Ved første kørsel som Administrator registreres `TU-ACME` automatisk som Event Log-kilde i `Application`-loggen. Verificér:

```powershell
Get-EventLog -LogName Application -Source TU-ACME -Newest 5
```

---

## 6. Valgfri: IIS-integration

Hvis TU-ACME skal opdatere IIS HTTPS-bindings automatisk ved certifikatfornyelse:

### 6.1 Registrér post-renewal plugin

I TUI'en: **6. IIS Integration → Opsæt automatisk IIS-opdatering**

Eller manuelt:

```powershell
$scriptPath = "$env:ProgramFiles\WindowsPowerShell\Modules\TU-ACME\Scripts\Posh-ACME-IIS-Plugin.ps1"
Set-PAConfig -PostScript $scriptPath
```

### 6.2 Kobl eksisterende certifikater til IIS

I TUI'en: **6. IIS Integration → Kobl certifikat til IIS-binding**

Vælg certifikat → vælg bindings (mellemrum = toggle) → bekræft.

---

## 7. Valgfri: Automatisk fornyelse

### 7.1 Konfigurér SMTP (valgfrit — til fejladvisering)

I TUI'en: **4. Automatisering → Konfigurer SMTP-fejladvisering**

Angiv SMTP-server, port, afsender og modtager. Test med "Send test-mail".

### 7.2 Opret Scheduled Task

I TUI'en: **4. Automatisering → Opret Scheduled Task**

Eller manuelt:

```powershell
$scriptPath = "$env:ProgramFiles\WindowsPowerShell\Modules\TU-ACME\Scripts\Invoke-RenewalBackground.ps1"

$action   = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger  = New-ScheduledTaskTrigger -Daily -At '03:00'
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 2) -StartWhenAvailable
$principal= New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest

Register-ScheduledTask -TaskName 'Posh-ACME-AutoRenewal' `
    -Action $action -Trigger $trigger -Settings $settings -Principal $principal
```

### 7.3 Verificér Scheduled Task

```powershell
# Vis task-status
Get-ScheduledTask -TaskName 'Posh-ACME-AutoRenewal'

# Kør manuelt til test
Start-ScheduledTask -TaskName 'Posh-ACME-AutoRenewal'

# Tjek Event Log for resultat
Get-EventLog -LogName Application -Source TU-ACME -Newest 10
```

---

## 8. Afinstallation

```powershell
# 1. Fjern Scheduled Task
Unregister-ScheduledTask -TaskName 'Posh-ACME-AutoRenewal' -Confirm:$false

# 2. Fjern Posh-ACME post-renewal plugin
Set-PAConfig -PostScript $null

# 3. Fjern TU-ACME modul
Remove-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\TU-ACME" -Recurse -Force

# 4. Fjern konfigurationsdata (ADVARSEL: sletter credentials og indstillinger)
Remove-Item -Path "$env:ProgramData\TU-ACME" -Recurse -Force

# 5. Fjern Event Log-kilde (valgfrit)
Remove-EventLog -Source 'TU-ACME'
```

> Posh-ACME og dets certifikat-data i `$env:LOCALAPPDATA\Posh-ACME\` berøres ikke.

---

## 9. Fejlfinding

### TU-ACME starter ikke — "Posh-ACME modulet er ikke installeret"

```powershell
# Kontrollér at Posh-ACME er installeret for AllUsers
Get-Module -ListAvailable Posh-ACME

# Geninstallér
Install-Module -Name Posh-ACME -Scope AllUsers -Force
```

### "Access Denied" ved oprettelse af config-mappe

```powershell
# TU-ACME kræver skriverettigheder til ProgramData ved første opstart
# Kør PowerShell som Administrator
```

### Event Log-kilde kan ikke registreres

```powershell
# Registrér manuelt som Administrator
New-EventLog -LogName Application -Source 'TU-ACME'
```

### Scheduled Task kører ikke som SYSTEM

```powershell
# Verificér at Posh-ACME er installeret for AllUsers (ikke kun CurrentUser)
Get-Module -ListAvailable Posh-ACME

# SYSTEM-kontoen kan kun se moduler installeret under AllUsers-stien:
# $env:ProgramFiles\WindowsPowerShell\Modules\
```

### DPAPI-fejl ved indlæsning af SMTP-credentials

SMTP-credentials er krypteret med DPAPI bundet til brugeren og maskinen der gemte dem. De kan ikke flyttes til en anden maskine eller bruger.

```powershell
# Genkonfigurér SMTP-credentials på den aktuelle maskine:
# TUI: 4. Automatisering -> Konfigurer SMTP-fejladvisering
```

### DNS-validering timeout

Øg `DnsSleep` i TUI'en ved næste certifikatbestilling:  
**2. Bestil nyt certifikat → DNS-01 Challenge-indstillinger → DNS-sleep: 300**

Eller opdatér standard i config:

```powershell
$config = Get-Content "$env:ProgramData\TU-ACME\config.json" | ConvertFrom-Json
$config.DNS.DefaultDnsSleep = 300
$config | ConvertTo-Json -Depth 5 | Set-Content "$env:ProgramData\TU-ACME\config.json"
```
