# Installing TU-ACME

## Prerequisites

- Windows Server 2016+ or Windows 10/11 with **Windows PowerShell 5.1**. Run `$PSVersionTable.PSVersion` to confirm.
- Administrator rights on the target machine.
- Posh-ACME from the PowerShell Gallery:

  ```powershell
  Install-Module -Name Posh-ACME -Scope AllUsers
  ```

  `deploy.ps1` will install Posh-ACME automatically if it is missing.

- Network connectivity to the internal corporate ACME CA endpoints (both production and staging URLs).

## Install via deploy.ps1

From an elevated PowerShell prompt in a clone of this repository:

```powershell
.\deploy.ps1
```

`deploy.ps1` copies the `TU-ACME` folder into `$env:ProgramFiles\WindowsPowerShell\Modules\TU-ACME\` (the AllUsers module path), so the module is discoverable for every user on the box, including the SYSTEM account that the background renewal task runs as.

To install manually, copy the `TU-ACME` directory into:

```
C:\Program Files\WindowsPowerShell\Modules\TU-ACME\
```

## First-run wizard

The very first time `Start-TUACME` runs, it walks the administrator through a short wizard:

1. **Production ACME URL** — the directory URL for your internal corporate CA's production endpoint.
2. **Staging ACME URL** — the directory URL for your internal corporate CA's staging endpoint, used for dry-runs.
3. **Contact email** — the address registered against both accounts.

TU-ACME then creates one prod account and one staging account against those URLs and writes the configuration to `%ProgramData%\TU-ACME\config.json`. You will never be asked to pick an account again — every flow routes itself.

## Verify the install

```powershell
Get-Module -ListAvailable TU-ACME
```

You should see a single entry pointing at `C:\Program Files\WindowsPowerShell\Modules\TU-ACME\TU-ACME.psd1` with the current `ModuleVersion`. Launch the TUI with:

```powershell
Import-Module TU-ACME
Start-TUACME
```

If the first-run wizard does not appear on a fresh machine, delete `%ProgramData%\TU-ACME\` and try again. See [SMOKE-TEST.md](./SMOKE-TEST.md) for the full post-install validation walkthrough.
