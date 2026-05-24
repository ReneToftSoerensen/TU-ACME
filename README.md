# TU-ACME

A Windows PowerShell 5.1 TUI wrapper around [Posh-ACME](https://github.com/rmbolger/Posh-ACME) for an internal corporate ACME certificate authority. TU-ACME owns its own prod and staging accounts, so operators never have to think about which account is active — the module routes every certificate operation to the right one automatically.

## What is TU-ACME

- Single entry point: `Start-TUACME` opens a console-based menu.
- Two accounts, created at first run: one against the production internal CA, one against the staging internal CA. The module switches between them based on the flow (real orders → prod, dry-runs → staging).
- No graphical dependencies. Runs on a stock Windows Server with PowerShell 5.1.
- Background renewal under the SYSTEM account uses the same prod account as the interactive user.

## Install

See [INSTALL.md](./INSTALL.md) for the full guide. Quick version:

```powershell
# From an elevated PowerShell prompt in a clone of this repo:
.\deploy.ps1
```

`deploy.ps1` copies the module into `$env:ProgramFiles\WindowsPowerShell\Modules\TU-ACME\` so every user (including SYSTEM) can import it.

## Usage

```powershell
Import-Module TU-ACME
Start-TUACME
```

The first run prompts for the production ACME URL, the staging ACME URL, and a contact email. Subsequent runs read the saved config from `%ProgramData%\TU-ACME\` and go straight to the main menu.

## Requirements

- Windows PowerShell 5.1 (Windows Server 2016+ or Windows 10/11 ship with this).
- [Posh-ACME](https://www.powershellgallery.com/packages/Posh-ACME) — installed automatically by `deploy.ps1` if missing.
- Network access to your internal corporate ACME CA. TU-ACME is not designed for Let's Encrypt or any other public CA.
- Administrator rights for first-run setup, certificate-store import, scheduled-task creation, and IIS rebind.

## Where to go next

- [INSTALL.md](./INSTALL.md) — step-by-step install and first-run wizard.
- [SMOKE-TEST.md](./SMOKE-TEST.md) — manual end-to-end checklist after install.
- [CLAUDE.md](./CLAUDE.md) — project conventions, locked decisions, folder layout, and event-ID registry.
