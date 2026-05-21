# TU-ACME

An interactive text-based terminal user interface (TUI) for the PowerShell module [Posh-ACME](https://github.com/rmbolger/Posh-ACME). Manage Let's Encrypt certificates, DNS validation, automatic renewal, and IIS integration — all directly from the terminal.

---

## Features

| Category | Feature |
|---|---|
| **Account management** | Create, switch, and manage ACME accounts (Production/Staging) |
| **Certificates** | Order certificates with DNS validation and a real-time status indicator |
| **DNS plugins** | Supports all Posh-ACME DNS plugins (Azure, Cloudflare, Route53, and more) |
| **Dashboard** | Color-coded overview of certificate status and expiration dates |
| **Automation** | Windows Scheduled Task for nightly renewal with email notification on failure |
| **Export/Import** | Export to PFX, PEM/CRT/KEY, or import directly into the Windows Certificate Store |
| **IIS integration** | Scan, bind, and update IIS HTTPS bindings automatically on renewal |
| **Troubleshooting** | Read and export Posh-ACME log files directly in the TUI |

---

## Requirements

- **OS:** Windows (Windows 10/11, Windows Server 2016 and newer, including Server Core)
- **PowerShell:** 5.0 or newer
- **Posh-ACME:** Installed via `Install-Module Posh-ACME`
- **Administrator privileges:** Required for IIS administration and creating Scheduled Tasks
- **IIS features** *(only for UC-8.x)*: Internet Information Services with the `WebAdministration` module

---

## Installation

```powershell
# 1. Install Posh-ACME if it is not already installed
Install-Module -Name Posh-ACME -Scope AllUsers

# 2. Clone or download this repository
git clone https://github.com/renetoftsoerensen/tu-acme.git
cd tu-acme

# 3. Start the TUI (run as Administrator for full access)
.\Scripts\Start-TUACME.ps1
```

---

## Usage

Start the TUI in a PowerShell session. For full functionality (IIS, Scheduled Tasks), PowerShell must be run as Administrator.

```
TU-ACME v0.4.5
==========================================
Active account: admin@example.com | Let's Encrypt Production

  1. Account Management
  2. Order new certificate
  3. Certificate dashboard
  4. Automation
  5. Export / Import
  6. IIS Integration
  7. Troubleshooting / Logs
  Q. Quit

[F3] Switch to Staging   [F1] Help
```

Navigate with the **arrow keys**, select with **Enter**, and go back with **ESC** or **Q**.

---

## Use Cases

All features are documented as atomic use cases in the [`Usecases/`](./Usecases/) folder:

| ID | Description | Priority |
|---|---|---|
| UC-0.1 | Check administrator privileges at startup | High |
| UC-1.1 | Show list of existing ACME accounts | High |
| UC-1.2 | Create new ACME account | High |
| UC-1.3 | Switch active ACME account | High |
| UC-1.4 | Quick switch to Staging/Test environment | High |
| UC-2.1 | Enter domain name and alternative names (SAN) | High |
| UC-2.2 | Order certificate and show real-time status indicator | High |
| UC-3.1 | Show supported DNS plugins in menu | High |
| UC-3.2 | Enter and mask API credentials in prompt | High |
| UC-3.3 | Store API credentials encrypted on disk | High |
| UC-4.1 | Show interactive table of certificates (color-coded) | High |
| UC-4.2 | Sort and filter the certificate list | Medium |
| UC-4.3 | Show detailed information about a selected certificate | Medium |
| UC-5.1 | Create Windows Scheduled Task for nightly run | High |
| UC-5.2 | Configure and save SMTP settings for email | High |
| UC-5.3 | Test SMTP connection and send test email from the TUI | Medium |
| UC-5.4 | Run silent background renewal with error collection | High |
| UC-6.1 | Export certificate to PFX file | Medium |
| UC-6.2 | Export certificate to PEM/Key/Cert files | Medium |
| UC-6.3 | Import certificate directly into Windows Certificate Store | High |
| UC-7.1 | Browse recent log files directly in the TUI (pager) | Medium |
| UC-7.2 | Export log files to an external file | Low |
| UC-8.1 | Scan local IIS sites and HTTPS bindings | High |
| UC-8.2 | Bind certificate to IIS endpoints manually via the TUI | High |
| UC-8.3 | Register Post-Renewal Plugin (IIS Update) in Posh-ACME | High |
| UC-8.4 | Automatic IIS update via Post-Renewal script | High |

---

## Security

- API keys and passwords are **never stored in plain text**. All secret information is encrypted with Windows DPAPI via PowerShell's `Export-Clixml`.
- The TUI automatically detects whether it is running with elevated privileges and disables administrative functions if not (UC-0.1).
- Encrypted data is bound to the user and machine that saved it — and cannot be read by other users or on other machines.

---

## Automatic renewal

Once automation is configured (UC-5.1), renewal runs nightly without user interaction:

```
Task Scheduler (03:00)
  +-- Invoke-RenewalBackground.ps1
        +-- Submit-Renewal (Posh-ACME)
              +-- [Success]  -> Log to Windows Event Log
              +-- [Failure]  -> Send error email to administrator (UC-5.4)
              +-- [Renewed]  -> Trigger Posh-ACME-IIS-Plugin.ps1 (UC-8.4)
                                  +-- Update IIS bindings automatically
```

---

## License

See [LICENSE](./LICENSE) for license terms.
