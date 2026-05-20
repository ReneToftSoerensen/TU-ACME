# UC-0.0: Technical Stack and Specifications

**Category:** System — Architecture and implementation decisions  
**Priority:** High (foundation for all other UCs)

---

## 1. PowerShell version and compatibility

| Parameter | Decision |
|---|---|
| **Target version** | Windows PowerShell **5.1** |
| **Compatibility** | PS 5.1 only — no PS 7.x-specific APIs |
| **Rationale** | Matches Posh-ACME's own minimum requirement and is the default on all Windows Server versions (2016+) and Windows 10/11 |

### Implications for the code
- Use `[System.Console]` and `$Host.UI.RawUI` — no `PSReadLine` dependencies.
- Avoid PS 7-only features: `ForEach-Object -Parallel`, the `??=` operator, ternary `? :` expressions.
- Test on PS 5.1 before pushing.

---

## 2. TUI navigation and console handling

| Parameter | Decision |
|---|---|
| **Method** | **Pure console I/O** (`$Host.UI.RawUI`, `[Console]::ReadKey()`) |
| **External modules** | None — zero-dependency TUI |
| **Rationale** | Works everywhere: local session, Server Core, WinRM/SSH remoting, headless |

### Key APIs
```powershell
# Read a single keystroke (non-blocking)
$key = [Console]::ReadKey($true)

# Move the cursor
[Console]::SetCursorPosition($col, $row)

# Console width and height
$width  = [Console]::WindowWidth
$height = [Console]::WindowHeight

# Colored text
Write-Host "Text" -ForegroundColor Green -BackgroundColor Black

# Hidden input (passwords)
$secure = Read-Host -AsSecureString "API Token"
```

### Spinner animation (UC-2.2)
```powershell
$frames = @('/', '-', '\', '|')
$i = 0
while ($running) {
    Write-Host "`r[ $($frames[$i % 4]) ] Validating..." -NoNewline
    $i++; Start-Sleep -Milliseconds 150
}
```

---

## 3. Distribution format

| Parameter | Decision |
|---|---|
| **Format** | **PowerShell module** (`.psm1` + manifest `.psd1`) |
| **Install path** | `$env:ProgramFiles\WindowsPowerShell\Modules\TU-ACME\` (AllUsers) |
| **Rationale** | The module format provides a clean namespace, version management, and availability for all users including the SYSTEM account (required for Scheduled Tasks) |

### Folder structure for the module
```
TU-ACME\
├── TU-ACME.psd1          # Module manifest (version, dependencies)
├── TU-ACME.psm1          # Main module file (dot-sources Private + Public)
├── Public\
│   └── Start-TUACME.ps1  # Exported entry point
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
    └── Posh-ACME-IIS-Plugin.ps1   # Post-renewal script for IIS
```

### Installation
```powershell
# Requires Administrator
Copy-Item -Path ".\TU-ACME" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\" -Recurse
Import-Module TU-ACME
Start-TUACME
```

---

## 4. Configuration file

| Parameter | Decision |
|---|---|
| **Format** | **JSON** for non-secret settings |
| **Path** | `$env:ProgramData\TU-ACME\config.json` |
| **Secret data** | `$env:ProgramData\TU-ACME\smtp-credentials.xml` (encrypted via `Export-Clixml` / DPAPI) |
| **Rationale** | ProgramData is accessible to all users and the SYSTEM account. JSON is human-readable and easy to debug |

### Configuration file structure (`config.json`)
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
    "SenderAddress": "noreply@example.com",
    "RecipientAddress": "admin@example.com"
  },
  "Dashboard": {
    "WarnDaysThreshold": 30,
    "DefaultSort": "ExpiryAscending"
  },
  "DNS": {
    "DefaultDnsSleep": 120,
    "DefaultValidationTimeout": 60,
    "PersistentRecords": false
  }
}
```

### SMTP credentials (`smtp-credentials.xml`)
```powershell
# Save encrypted (DPAPI — bound to user/machine)
[PSCustomObject]@{
    Username = $smtpUser
    Password = $smtpPassword   # SecureString
} | Export-Clixml -Path "$env:ProgramData\TU-ACME\smtp-credentials.xml"

# Load
$creds = Import-Clixml -Path "$env:ProgramData\TU-ACME\smtp-credentials.xml"
```

---

## 5. IIS integration

| Parameter | Decision |
|---|---|
| **Scope** | **Local IIS only** |
| **Matching method** | **Thumbprint match** (certificateHash) |
| **Module** | `WebAdministration` (standard with IIS on Windows Server) |

### Thumbprint matching in the post-renewal script (UC-8.4)
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

## 6. Email format (failure notification)

| Parameter | Decision |
|---|---|
| **Format** | **Plaintext** |
| **Sending** | `Send-MailMessage` (built into PS 5.1) |

### Email template (UC-5.4)
```
Subject: [TU-ACME] FAILURE during certificate renewal - example.com

Timestamp:    2026-05-18 03:01:55
Server:       WIN-SERVER01
Domain:       example.com
Error type:   DNS validation failed
Error:        [exact error from Posh-ACME]

Action required:
Check certificate status in TU-ACME or run:
  Submit-Renewal -Force -Domain "example.com"

Log file:
  C:\ProgramData\TU-ACME\renewal.log

-- Sent automatically by TU-ACME --
```

---

## 7. Windows Event Log

| Parameter | Decision |
|---|---|
| **Log** | `Application` |
| **Source** | `TU-ACME` |
| **Registration** | Happens automatically on the first run as Administrator |

```powershell
# Register source (requires admin, only once)
if (-not [System.Diagnostics.EventLog]::SourceExists("TU-ACME")) {
    New-EventLog -LogName Application -Source "TU-ACME"
}

# Write to the log
Write-EventLog -LogName Application -Source "TU-ACME" `
    -EventId 1001 -EntryType Information `
    -Message "Certificate renewed: example.com. New thumbprint: A1B2C3..."
```

### Event ID convention
| Event ID | Type | Description |
|---|---|---|
| 1001 | Information | Certificate renewed successfully |
| 1002 | Information | IIS binding updated |
| 2001 | Warning | Certificate expires within 30 days (not yet renewed) |
| 3001 | Error | Certificate renewal failed |
| 3002 | Error | IIS binding update failed |

---

## 8. Summary: Technical stack

| Component | Choice |
|---|---|
| Runtime | Windows PowerShell 5.1 |
| TUI engine | Pure console I/O (`[Console]`, `$Host.UI.RawUI`) |
| Distribution | PowerShell module (`.psm1` + `.psd1`) |
| Install path | `$env:ProgramFiles\WindowsPowerShell\Modules\TU-ACME\` (AllUsers) |
| Configuration | JSON (`$env:ProgramData\TU-ACME\config.json`) |
| Secret data | `Export-Clixml` DPAPI encryption (`.xml`) |
| Email | `Send-MailMessage` plaintext |
| IIS scope | Local IIS with thumbprint matching |
| Logging | Windows Event Log (Application / TU-ACME) |
| Post-renewal | `Posh-ACME-IIS-Plugin.ps1` via `Set-PAConfig -PostScript` |
