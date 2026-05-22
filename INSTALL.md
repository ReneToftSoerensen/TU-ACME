# Installing TU-ACME

## Table of Contents

1. [System requirements](#1-system-requirements)
2. [Prerequisites](#2-prerequisites)
3. [Installation](#3-installation)
4. [Configuring data folders](#4-configuring-data-folders)
5. [First run](#5-first-run)
6. [Optional: IIS integration](#6-optional-iis-integration)
7. [Optional: Automatic renewal](#7-optional-automatic-renewal)
8. [Uninstallation](#8-uninstallation)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. System requirements

| Requirement | Minimum | Recommended |
|---|---|---|
| Operating system | Windows Server 2016 / Windows 10 | Windows Server 2019+ / Windows 11 |
| PowerShell | 5.1 | 5.1 (only) — PS 7.x is not supported |
| Permissions | User (dashboard/logs) | Administrator (certificates, IIS, Tasks) |
| Network | Outbound HTTPS (port 443) to ACME server and DNS provider API | — |
| Disk space | < 5 MB | — |

> **Windows Server Core:** Fully supported. The TUI uses console I/O exclusively.  
> **PowerShell Remoting (WinRM/SSH):** Supported — no graphical dependencies.

---

## 2. Prerequisites

### 2.1 Install Posh-ACME

TU-ACME is a TUI wrapper for [Posh-ACME](https://github.com/rmbolger/Posh-ACME) and requires it to be installed.

```powershell
# Requires Administrator — installs for all users (including the SYSTEM account)
Install-Module -Name Posh-ACME -Scope AllUsers -Force
```

Verify the installation:

```powershell
Get-Module -ListAvailable Posh-ACME
# Expected output: Version 4.x.x or newer
```

### 2.2 PowerShell Execution Policy

Scripts must have permission to run:

```powershell
# Show current policy
Get-ExecutionPolicy -List

# Set policy to RemoteSigned (recommended minimum)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

### 2.3 IIS (only for IIS integration)

If the IIS features (UC-8.x) are to be used, the `WebAdministration` module must be available:

```powershell
# Verify that WebAdministration is installed
Get-Module -ListAvailable WebAdministration

# Install IIS Management Tools if missing (Windows Server)
Install-WindowsFeature -Name Web-Mgmt-Tools
```

---

## 3. Installation

### Step 1: Download TU-ACME

**Option A — Git clone (recommended):**

```powershell
git clone https://github.com/renetoftsoerensen/tu-acme.git
cd tu-acme
```

**Option B — Download ZIP:**

Download and extract `tu-acme.zip` to a folder on the server.

---

### Step 2: Copy module to PowerShell module path

The repo ships a `deploy.ps1` that handles unload + wipe + copy + verify:

```powershell
# Requires Administrator. Run from the repo root.
.\deploy.ps1
```

Manual equivalent if you prefer to inline it:

```powershell
$moduleDest = "$env:ProgramFiles\WindowsPowerShell\Modules\TU-ACME"

# Unload from current session and remove the old install (if any).
# Copy-Item -Recurse -Force does NOT overwrite an existing directory
# cleanly on PS 5.1 — it nests the source inside, which leaves stale
# files (and the wrong ModuleVersion). Wipe first, then copy.
Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
if (Test-Path $moduleDest) {
    Remove-Item -Path $moduleDest -Recurse -Force
}

Copy-Item -Path ".\TU-ACME" -Destination $moduleDest -Recurse -Force

# Verify that the module can be found
Get-Module -ListAvailable TU-ACME
```

Expected output:

```
ModuleType  Version  Name      ExportedCommands
----------  -------  ----      ----------------
Script      0.9.2    TU-ACME   Start-TUACME
```

---

### Step 3: Import and start

```powershell
Import-Module TU-ACME
Start-TUACME
```

> **Tip:** Always run PowerShell as Administrator for full access to all functions.  
> If you start as a regular user, dashboard and log viewing are available — administrative functions (IIS, Tasks) are disabled automatically.

---

## 4. Configuring data folders

TU-ACME automatically creates these folders on first startup:

| Path | Contents |
|---|---|
| `$env:ProgramData\TU-ACME\` | Root folder for configuration and credentials |
| `$env:ProgramData\TU-ACME\config.json` | Non-secret settings (SMTP, Task, Dashboard, DNS) |
| `$env:ProgramData\TU-ACME\smtp-credentials.xml` | SMTP credentials (DPAPI-encrypted) |
| `$env:ProgramData\TU-ACME\acmedns-accounts\` | ACME-DNS account JSON files (one per domain) |

The folders are created with standard Windows permissions — accessible to all users and the `SYSTEM` account.

### Create manually (optional)

```powershell
New-Item -ItemType Directory -Path "$env:ProgramData\TU-ACME" -Force
```

---

## 5. First run

### 5.1 Start the TUI

```powershell
# Start as Administrator (recommended)
Start-TUACME
```

### 5.2 Create ACME account

Choose **1. Account Management -> Create new account** and enter:

- **Email:** Administrator's email address (used for expiration warnings from Let's Encrypt)
- **Server:** Let's Encrypt Production (or Staging for testing)

```
Recommendation: Always test on Staging (F3) before ordering production certificates.
Let's Encrypt has rate limits on the production server.
```

### 5.3 Register Windows Event Log source

On first run as Administrator, `TU-ACME` is registered automatically as an Event Log source in the `Application` log. Verify:

```powershell
Get-EventLog -LogName Application -Source TU-ACME -Newest 5
```

---

## 6. Optional: IIS integration

If TU-ACME should automatically update IIS HTTPS bindings on certificate renewal:

### 6.1 Post-renewal IIS rebind

Posh-ACME v4 has no native `-PostScript` hook, so TU-ACME's renewal
wrapper (`Invoke-RenewalBackground.ps1`) handles IIS rebinding itself.
It snapshots `Get-PACertificate -List` thumbprints before
`Submit-Renewal`, snapshots again after, and for every cert whose
thumbprint changed it calls the rebind logic in
`Posh-ACME-IIS-Plugin.ps1`. No registration required — install the
Scheduled Task (Section 7.2) and rebinding happens automatically on
every renewal.

To test the rebind logic manually with a known old/new thumbprint pair:

```powershell
$scriptPath = "$env:ProgramFiles\WindowsPowerShell\Modules\TU-ACME\Scripts\Posh-ACME-IIS-Plugin.ps1"
& $scriptPath -OldThumbprint <old> -Thumbprint <new> -CertFile <path-to-pfx>
```

### 6.2 Bind existing certificates to IIS

In the TUI: **6. IIS Integration -> Bind certificate to IIS binding**

Select certificate -> select bindings (spacebar = toggle) -> confirm.

---

## 7. Optional: Automatic renewal

### 7.1 Configure SMTP (optional — for failure notifications)

In the TUI: **4. Automation -> Configure SMTP failure notifications**

Enter SMTP server, port, sender and recipient. Test with "Send test email".

### 7.2 Create Scheduled Task

In the TUI: **4. Automation -> Create Scheduled Task**

Or manually:

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

### 7.3 Verify Scheduled Task

```powershell
# Show task status
Get-ScheduledTask -TaskName 'Posh-ACME-AutoRenewal'

# Run manually to test
Start-ScheduledTask -TaskName 'Posh-ACME-AutoRenewal'

# Check Event Log for result
Get-EventLog -LogName Application -Source TU-ACME -Newest 10
```

---

## 8. Uninstallation

```powershell
# 1. Remove Scheduled Task
Unregister-ScheduledTask -TaskName 'Posh-ACME-AutoRenewal' -Confirm:$false

# 2. Remove TU-ACME module
Remove-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\TU-ACME" -Recurse -Force

# 3. Remove configuration data (WARNING: deletes credentials and settings)
Remove-Item -Path "$env:ProgramData\TU-ACME" -Recurse -Force

# 4. Remove Event Log source (optional)
Remove-EventLog -Source 'TU-ACME'
```

> Posh-ACME and its certificate data in `$env:LOCALAPPDATA\Posh-ACME\` are not affected.

---

## 9. Troubleshooting

### TU-ACME does not start — "Posh-ACME module is not installed"

```powershell
# Verify that Posh-ACME is installed for AllUsers
Get-Module -ListAvailable Posh-ACME

# Reinstall
Install-Module -Name Posh-ACME -Scope AllUsers -Force
```

### "Access Denied" when creating config folder

```powershell
# TU-ACME requires write permissions to ProgramData on first startup
# Run PowerShell as Administrator
```

### Event Log source cannot be registered

```powershell
# Register manually as Administrator
New-EventLog -LogName Application -Source 'TU-ACME'
```

### Scheduled Task does not run as SYSTEM

```powershell
# Verify that Posh-ACME is installed for AllUsers (not only CurrentUser)
Get-Module -ListAvailable Posh-ACME

# The SYSTEM account can only see modules installed under the AllUsers path:
# $env:ProgramFiles\WindowsPowerShell\Modules\
```

### DPAPI error loading SMTP credentials

SMTP credentials are encrypted with DPAPI bound to the user and machine that saved them. They cannot be moved to another machine or user.

```powershell
# Reconfigure SMTP credentials on the current machine:
# TUI: 4. Automation -> Configure SMTP failure notifications
```

### DNS validation timeout

Increase `DnsSleep` in the TUI on the next certificate order:  
**2. Order new certificate -> DNS-01 Challenge settings -> DNS-sleep: 300**

Or update the default in config:

```powershell
$config = Get-Content "$env:ProgramData\TU-ACME\config.json" | ConvertFrom-Json
$config.DNS.DefaultDnsSleep = 300
$config | ConvertTo-Json -Depth 5 | Set-Content "$env:ProgramData\TU-ACME\config.json"
```
