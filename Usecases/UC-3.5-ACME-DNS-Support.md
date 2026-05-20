# UC-3.5: ACME-DNS support

**Category:** DNS plugins and credentials  
**Priority:** High  
**Depends on:** UC-3.1 (Show DNS plugins), UC-3.4 (DNS-01 challenge configuration)

---

## Goal

Support [acme-dns](https://github.com/joohoi/acme-dns) as a DNS-01 challenge method.  
ACME-DNS is a minimal, dedicated DNS server with a REST API that exclusively handles ACME TXT records - without requiring access to the entire DNS zone.

---

## Background: what is ACME-DNS?

```
Traditional DNS-01:
  Certificate client -> direct access to DNS provider API

ACME-DNS:
  Certificate client -> ACME-DNS server (REST API)
                           |
                           v
             _acme-challenge.<your-domain>
             CNAME -> <subdomain>.acme-dns-server.com

Advantages:
  - Restricted DNS access - API keys grant access only to the ACME subdomain
  - Works with DNS providers that have no API (only a CNAME record is required, once, manually)
  - Wildcard certificates without full DNS-API access
  - Well suited to production environments with strict security requirements
```

---

## Actors

- System administrator

---

## Preconditions

- An ACME-DNS server is available (either self-hosted or public, e.g. `https://auth.acme-dns.io`)
- Posh-ACME is installed with the AcmeDns plugin

---

## Setup flow (first time)

### Step 1: Select the ACME-DNS plugin

In the plugin list, `AcmeDns` is shown as an option. When it is selected, the TUI starts a guided setup instead of the generic plugin-args dialog.

### Step 2: Specify the ACME-DNS server

```
  === ACME-DNS setup ===

  ACME-DNS server URL:
  Examples:
    https://auth.acme-dns.io       (public test server)
    https://acmedns.example.com    (self-hosted)

  > Server URL: _
```

### Step 3: Register a new account (or load an existing one)

```
  Do you already have an ACME-DNS account for this domain? (Y/N)

  Y -> Specify the existing account JSON
  N -> Register a new account automatically
```

**New registration:**

```
  Registering an account on auth.acme-dns.io...

  Account created!
  +---------------------------------------------------------+
  | Username:   a0b1c2d3-xxxx-xxxx-xxxx-xxxxxxxxxxxx       |
  | Password:   xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    |
  | Subdomain:  a0b1c2d3-xxxx-xxxx-xxxx-xxxxxxxxxxxx       |
  | FullDomain: a0b1c2d3-xxxx.auth.acme-dns.io             |
  +---------------------------------------------------------+
```

### Step 4: CNAME instruction

The TUI displays the CNAME record that must be created manually in the DNS zone (this is done only once):

```
  +---------------------------------------------------------------------+
  |  ACTION REQUIRED - Create the following CNAME record at your DNS   |
  |  provider BEFORE you continue:                                      |
  |                                                                     |
  |  Name:   _acme-challenge.example.com                                |
  |  Type:   CNAME                                                      |
  |  Value:  a0b1c2d3-xxxx.auth.acme-dns.io.                            |
  |  TTL:    300 (or as low as possible)                                |
  |                                                                     |
  |  This record is created ONLY ONCE and is permanent.                 |
  +---------------------------------------------------------------------+

  Press [Enter] when the CNAME record has been created and propagated...
```

### Step 5: Store credentials

The account JSON is stored encrypted:

```
  $env:ProgramData\TU-ACME\acmedns-<domain>.json  <- DPAPI-encrypted via Export-Clixml
```

Alternatively, credentials are stored in Posh-ACME's own `PluginArgs` mechanism (UC-3.3).

---

## Renewal flow (subsequent runs)

During automatic renewal (UC-5.4), the stored credentials are reused without user interaction:

```powershell
$pArgs = @{
    ACMEDnsServer      = 'https://auth.acme-dns.io'
    ACMEDnsAccountJson = $encryptedJsonPath   # path to encrypted file
}
New-PACertificate -Domain 'example.com' -Plugin AcmeDns -PluginArgs $pArgs
```

---

## Alternative flows

### ACME-DNS server not available

```
  [ERROR] Cannot connect to the ACME-DNS server:
  https://auth.acme-dns.io - Connection refused

  Verify that the server is reachable and that the URL is correct.
  Try again with [Enter] or abort with [ESC].
```

### Loading an existing account JSON

The user can specify the path to an existing account JSON (e.g. generated outside the TUI):

```
  > Path to account JSON: C:\PoshACME\acmedns-account.json
  Loading... OK
  Username:  a0b1c2d3-xxxx...
  Subdomain: a0b1c2d3-xxxx...
```

### SAN / wildcard using the same ACME-DNS account

The same ACME-DNS account can be used for both wildcard and base domain:

```
  Domains shared with this ACME-DNS account:
    example.com
    *.example.com

  -> Both point to the same CNAME: _acme-challenge.example.com
```

---

## Technical notes

### Posh-ACME AcmeDns plugin parameters

| Parameter | Type | Description |
|---|---|---|
| `ACMEDnsServer` | String | URL of the ACME-DNS server |
| `ACMEDnsAccountJson` | String | Path to the JSON file with credentials |

### Account JSON structure (from the acme-dns server)

```json
{
  "username": "a0b1c2d3-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subdomain": "a0b1c2d3-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "fulldomain": "a0b1c2d3-xxxx.auth.acme-dns.io",
  "allowfrom": []
}
```

### Registration via REST API

```powershell
# Register a new ACME-DNS account
$response = Invoke-RestMethod -Uri "$server/register" -Method Post `
    -ContentType 'application/json' -Body '{}'
# Returns: username, password, subdomain, fulldomain

# Save the JSON to an encrypted file
$response | ConvertTo-Json | Set-Content -Path $jsonPath -Encoding UTF8
```

### Storage path convention

```
$env:ProgramData\TU-ACME\acmedns-accounts\<sanitized-domain>.json
```

The filename is sanitized: `example.com` -> `example_com.json`

---

## Acceptance criteria

- [ ] `AcmeDns` appears in the plugin list and triggers a guided ACME-DNS setup
- [ ] A new account can be registered automatically via the REST API with visual feedback
- [ ] An existing account JSON can be loaded from a file
- [ ] The CNAME instruction is shown clearly with the correct values before the user continues
- [ ] Credentials are stored encrypted under `$env:ProgramData\TU-ACME\acmedns-accounts\`
- [ ] During renewal, the stored credentials are reused without interaction
- [ ] Wildcard domains (`*.example.com`) are supported with the same ACME-DNS account
