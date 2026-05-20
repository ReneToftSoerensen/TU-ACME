# UC-3.4: DNS-01 challenge configuration

**Category:** DNS plugins and credentials  
**Priority:** High  
**Depends on:** UC-3.1 (Show DNS plugins), UC-3.2 (Masked credentials), UC-2.2 (Order certificate)

---

## Goal

Give the administrator control over the DNS-01 challenge parameters: propagation wait time (`DnsSleep`), validation timeout, and the option to keep DNS TXT records after a successful challenge (persistent mode).

---

## Actors

- System administrator

---

## Preconditions

- A DNS plugin has been selected (UC-3.1) and credentials have been loaded (UC-3.2)
- Posh-ACME is installed and configured with an active ACME account

---

## Background: the DNS-01 challenge flow

```
User orders a certificate
    |
    v
Posh-ACME creates a DNS TXT record:
    _acme-challenge.<domain> = "<token>"
    |
    v
Waits DnsSleep seconds (default: 120 sec)
    -- DNS propagation --
    |
    v
ACME server validates the TXT record
    |
    v
Certificate is issued
    |
    v
TXT record is deleted (unless persistent mode is active)
```

---

## Main flow

1. After the plugin and credentials have been selected (UC-3.1/3.2), the DNS-01 challenge configuration is shown:

```
  === DNS-01 challenge settings ===

  DNS propagation wait time (DnsSleep):
  Default: 120 seconds
  > Specify seconds (blank = default): _

  Validation timeout:
  Default: 60 seconds
  > Specify seconds (blank = default): _

  Persistent DNS records:
  [ ] Keep TXT records after validation (persistent mode)

  [Enter] Continue  [ESC] Abort
```

2. The user specifies DnsSleep (blank = keep default 120 sec).
3. The user specifies the validation timeout (blank = keep default 60 sec).
4. The user chooses whether DNS TXT records should be deleted after validation:
   - **Default (not persistent):** Records are deleted automatically by the plugin after validation
   - **Persistent mode:** Records are left in DNS - useful with slow DNS providers or for re-validation without setting up new credentials

5. The summary is updated with the DNS-01 parameters:
```
  === Summary ===

  Domain:          example.com
  Plugin:          Cloudflare
  Challenge:       DNS-01
  DNS sleep:       120 sec
  Timeout:         60 sec
  Persistent DNS:  No

  [Y] Confirm  [N] Abort
```

---

## Postconditions

- `New-PACertificate` is called with `-DnsSleep` and `-ValidationTimeout`
- The spinner shows the propagation phase:
  ```
  [ / ] Creating DNS TXT record...
  [ - ] Waiting for DNS propagation (120 sec)...
  [ \ ] Validating challenge with ACME server...
  [ | ] Receiving certificate...
  ```

---

## Alternative flows

### DNS propagation fails (timeout)

```
  [ERROR] DNS validation failed:
  The ACME server could not verify the TXT record before timeout.

  Possible causes:
  - DNS propagation is not yet complete
  - DnsSleep is too low for your DNS provider

  Recommendations:
  - Increase DnsSleep to 300+ seconds and try again
  - Verify that the TXT record was created correctly at your DNS provider
  - Use Staging for testing: [F3] Staging toggle
```

### Persistent mode enabled

When `Persistent mode` is selected, Posh-ACME does **not** call the plugin's `Remove-DnsTxt` function. The TXT record remains in DNS:

```powershell
# Persistent mode - using -NoSavePfxPass is not relevant here,
# Posh-ACME handles cleanup via the plugin contract
New-PACertificate -Domain $domains -Plugin $plugin -PluginArgs $pArgs `
    -DnsSleep $dnsSleep -ValidationTimeout $timeout
# Records are left behind when the plugin does not receive a cleanup call
```

> **Note:** Persistent DNS records can represent a minimal security risk because ACME tokens are visible in DNS. Records should be removed manually when they are no longer needed.

### Plugin does not support cleanup

Certain plugins (e.g. `Manual`) never support automatic cleanup - DNS is always persistent in those cases. The TUI displays:

```
  Note: The 'Manual' plugin requires manual creation and deletion
  of DNS TXT records. Records are not removed automatically.
```

---

## Technical notes

### Posh-ACME parameters

| Parameter | Default | Description |
|---|---|---|
| `-DnsSleep` | 120 | Seconds to wait after the TXT record has been created |
| `-ValidationTimeout` | 60 | Seconds that the ACME server has to validate |
| `-NoSkipManualEdit` | `$false` | Pause for manual DNS editing (Manual plugin) |

```powershell
New-PACertificate -Domain $domains `
    -Plugin $plugin `
    -PluginArgs $pArgs `
    -DnsSleep $dnsSleep `
    -ValidationTimeout $valTimeout `
    -AcceptTOS
```

### Storing DNS settings in config.json

DNS-01 settings are stored in `$env:ProgramData\TU-ACME\config.json` under a new section:

```json
{
  "DNS": {
    "DefaultDnsSleep": 120,
    "DefaultValidationTimeout": 60,
    "PersistentRecords": false
  }
}
```

This ensures that the settings are reused during renewal via the Scheduled Task (UC-5.4).

---

## Acceptance criteria

- [ ] DnsSleep and ValidationTimeout can be configured in the UI with blank = default
- [ ] Persistent mode can be enabled with an explicit warning about the security implications
- [ ] The spinner shows a clear status during each step of the DNS-01 flow
- [ ] The settings are saved in config.json and reused during automatic renewal
- [ ] Error messages on DNS timeout include concrete suggested solutions
