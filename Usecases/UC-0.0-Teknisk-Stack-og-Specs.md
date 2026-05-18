# UC-0.0: Teknisk Stack og Specifikationer

**Kategori:** System — Arkitektur og implementeringsbeslutninger  
**Prioritet:** Høj (fundament for alle øvrige UC'er)

---

## 1. PowerShell-version og kompatibilitet

| Parameter | Beslutning |
|---|---|
| **Målversion** | Windows PowerShell **5.1** |
| **Kompatibilitet** | Kun PS 5.1 — ingen PS 7.x-specifikke API'er |
| **Baggrund** | Matcher Posh-ACME's eget minimumskrav og er standard på alle Windows Server-versioner (2016+) og Windows 10/11 |

### Implikationer for koden
- Brug `[System.Console]` og `$Host.UI.RawUI` — ingen `PSReadLine`-afhængigheder.
- Undgå PS 7-only features: `ForEach-Object -Parallel`, `??=`-operatoren, ternary `? :`-udtryk.
- Test på PS 5.1 inden push.

---

## 2. TUI-navigation og konsolhåndtering

| Parameter | Beslutning |
|---|---|
| **Metode** | **Ren konsol I/O** (`$Host.UI.RawUI`, `[Console]::ReadKey()`) |
| **Eksterne moduler** | Ingen — zero-dependency TUI |
| **Baggrund** | Fungerer overalt: lokal session, Server Core, WinRM/SSH remoting, headless |

### Nøgle-API'er
```powershell
# Læs enkelt tastetryk (ikke-blokerende)
$key = [Console]::ReadKey($true)

# Flyt markøren
[Console]::SetCursorPosition($col, $row)

# Konsolbredde og -højde
$width  = [Console]::WindowWidth
$height = [Console]::WindowHeight

# Farvet tekst
Write-Host "Tekst" -ForegroundColor Green -BackgroundColor Black

# Skjult input (adgangskoder)
$secure = Read-Host -AsSecureString "API Token"
```

### Spinner-animation (UC-2.2)
```powershell
$frames = @('/', '-', '\', '|')
$i = 0
while ($running) {
    Write-Host "`r[ $($frames[$i % 4]) ] Validerer..." -NoNewline
    $i++; Start-Sleep -Milliseconds 150
}
```

---

## 3. Distributionsformat

| Parameter | Beslutning |
|---|---|
| **Format** | **PowerShell-modul** (`.psm1` + manifest `.psd1`) |
| **Install-sti** | `$env:ProgramFiles\WindowsPowerShell\Modules\PoshACME-TUI\` (AllUsers) |
| **Baggrund** | Modulformat giver clean namespace, versionstyring og tilgængelighed for alle brugere inkl. SYSTEM-kontoen (påkrævet til Scheduled Tasks) |

### Mappestruktur for modulet
```
PoshACME-TUI\
├── PoshACME-TUI.psd1          # Modul-manifest (version, afhængigheder)
├── PoshACME-TUI.psm1          # Hoved-modul-fil (dot-sources Private + Public)
├── Public\
│   └── Start-PoshACMETUI.ps1  # Eksporteret indgangspunkt
├── Private\
│   ├── UI\
│   │   ├── Show-Menu.ps1
│   │   ├── Show-Table.ps1
│   │   ├── Show-Spinner.ps1
│   │   └── Show-StatusBar.ps1
│   ├── Accounts\
│   │   └── Invoke-AccountMenu.ps1
│   ├── Certificates\
│   │   └── Invoke-CertificateMenu.ps1
│   ├── Automation\
│   │   └── Invoke-AutomationMenu.ps1
│   ├── IIS\
│   │   └── Invoke-IISMenu.ps1
│   └── Helpers\
│       ├── Get-AdminStatus.ps1
│       ├── ConvertTo-MaskedInput.ps1
│       └── Write-EventLogEntry.ps1
└── Scripts\
    └── Posh-ACME-IIS-Plugin.ps1   # Post-renewal script til IIS
```

### Installation
```powershell
# Kræver Administrator
Copy-Item -Path ".\PoshACME-TUI" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\" -Recurse
Import-Module PoshACME-TUI
Start-PoshACMETUI
```

---

## 4. Konfigurationsfil

| Parameter | Beslutning |
|---|---|
| **Format** | **JSON** til ikke-hemmelige indstillinger |
| **Sti** | `$env:ProgramData\PoshACME-TUI\config.json` |
| **Hemmelige data** | `$env:ProgramData\PoshACME-TUI\smtp-credentials.xml` (krypteret via `Export-Clixml` / DPAPI) |
| **Baggrund** | ProgramData er tilgængeligt for alle brugere og SYSTEM-kontoen. JSON er menneskelæsbart og nemt at debugge |

### Konfigurationsfilens struktur (`config.json`)
```json
{
  "Version": "1.0",
  "ScheduledTask": {
    "TaskName": "Posh-ACME-AutoRenewal",
    "RunTime": "03:00",
    "RunAsAccount": "SYSTEM"
  },
  "Email": {
    "SmtpServer": "smtp.office365.com",
    "SmtpPort": 587,
    "UseSsl": true,
    "UseAuth": true,
    "SenderAddress": "noreply@eksempel.dk",
    "RecipientAddress": "admin@eksempel.dk"
  },
  "Dashboard": {
    "WarnDaysThreshold": 30,
    "DefaultSort": "ExpiryAscending"
  }
}
```

### SMTP-credentials (`smtp-credentials.xml`)
```powershell
# Gem krypteret (DPAPI — bundet til bruger/maskine)
[PSCustomObject]@{
    Username = $smtpUser
    Password = $smtpPassword   # SecureString
} | Export-Clixml -Path "$env:ProgramData\PoshACME-TUI\smtp-credentials.xml"

# Indlæs
$creds = Import-Clixml -Path "$env:ProgramData\PoshACME-TUI\smtp-credentials.xml"
```

---

## 5. IIS-integration

| Parameter | Beslutning |
|---|---|
| **Scope** | **Kun lokal IIS** |
| **Matching-metode** | **Thumbprint-match** (certificateHash) |
| **Modul** | `WebAdministration` (standard med IIS på Windows Server) |

### Thumbprint-matching i post-renewal script (UC-8.4)
```powershell
Import-Module WebAdministration
$bindings = Get-WebBinding -Protocol "https" |
    Where-Object { $_.certificateHash -eq $OldThumbprint }
foreach ($binding in $bindings) {
    $binding.certificateHash = $NewThumbprint
    $binding | Set-WebBinding
}
```

---

## 6. E-mail-format (fejladvisering)

| Parameter | Beslutning |
|---|---|
| **Format** | **Plaintext** |
| **Afsendelse** | `Send-MailMessage` (PS 5.1 indbygget) |

### E-mail-skabelon (UC-5.4)
```
Emne: [Posh-ACME TUI] FEJL ved certifikatfornyelse - eksempel.dk

Tidsstempel:  2026-05-18 03:01:55
Server:       WIN-SERVER01
Domæne:       eksempel.dk
Fejltype:     DNS-validering mislykkedes
Fejlbesked:   [præcis fejl fra Posh-ACME]

Handling påkrævet:
Tjek certifikatstatus i Posh-ACME TUI eller kør:
  Submit-Renewal -Force -Domain "eksempel.dk"

Logfil:
  C:\ProgramData\PoshACME-TUI\renewal.log

-- Sendt automatisk af Posh-ACME TUI --
```

---

## 7. Windows Event Log

| Parameter | Beslutning |
|---|---|
| **Log** | `Application` |
| **Kilde** | `Posh-ACME-TUI` |
| **Registrering** | Sker automatisk ved første kørsel som Administrator |

```powershell
# Registrer kilde (kræver admin, kun én gang)
if (-not [System.Diagnostics.EventLog]::SourceExists("Posh-ACME-TUI")) {
    New-EventLog -LogName Application -Source "Posh-ACME-TUI"
}

# Skriv til log
Write-EventLog -LogName Application -Source "Posh-ACME-TUI" `
    -EventId 1001 -EntryType Information `
    -Message "Certifikat fornyet: eksempel.dk. Nyt thumbprint: A1B2C3..."
```

### Event ID-konvention
| Event ID | Type | Beskrivelse |
|---|---|---|
| 1001 | Information | Certifikat fornyet succesfuldt |
| 1002 | Information | IIS-binding opdateret |
| 2001 | Warning | Certifikat udløber inden for 30 dage (ikke fornyet endnu) |
| 3001 | Error | Certifikatfornyelse fejlet |
| 3002 | Error | IIS-binding opdatering fejlet |

---

## 8. Opsummering: Teknisk stack

| Komponent | Valg |
|---|---|
| Runtime | Windows PowerShell 5.1 |
| TUI-engine | Ren konsol I/O (`[Console]`, `$Host.UI.RawUI`) |
| Distribution | PowerShell-modul (`.psm1` + `.psd1`) |
| Install-sti | `$env:ProgramFiles\WindowsPowerShell\Modules\PoshACME-TUI\` (AllUsers) |
| Konfiguration | JSON (`$env:ProgramData\PoshACME-TUI\config.json`) |
| Hemmelige data | `Export-Clixml` DPAPI-kryptering (`.xml`) |
| E-mail | `Send-MailMessage` plaintext |
| IIS-scope | Lokal IIS med thumbprint-matching |
| Logging | Windows Event Log (Application / Posh-ACME-TUI) |
| Post-renewal | `Posh-ACME-IIS-Plugin.ps1` via `Set-PAConfig -PostScript` |
