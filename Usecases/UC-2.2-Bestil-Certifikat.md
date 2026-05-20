# UC-2.2: Order certificate and show real-time status indicator

**Category:** Certificate ordering  
**Priority:** High

## Goal
Provide visual feedback to the user while the ACME challenge and certificate ordering are running in the background.

## Actors
- System administrator (Admin)

## Preconditions
- Domain names are validated (UC-2.1).
- DNS plugin and credentials are configured (UC-3.1 / UC-3.2 / UC-3.3).

## Main flow
1. The user confirms the order via a summary view.
2. The TUI calls `New-PACertificate` with the specified parameters.
3. The TUI clears the screen and shows an animated spinner with status messages:
   ```
   [ / ] Creating certificate order...
   [ - ] Publishing DNS TXT record via plugin...
   [ \ ] Waiting for DNS propagation...
   [ | ] Validating ACME challenge...
   [ / ] Retrieving certificate...
   ```
4. On **success**: a green success message is shown:
   ```
   [OK] Certificate issued!
   Domain:      example.com
   Expires:     2026-08-18
   Thumbprint:  A1B2C3D4...
   ```
5. The TUI returns to the dashboard (UC-4.1) with the new certificate in the list.

## Postconditions
- The certificate is issued and stored by Posh-ACME.

## Alternative flows
- **3a:** DNS propagation takes too long -> the TUI shows a waiting indicator and a timeout countdown.
- **4a (Error):** A red error message is shown with the precise error message from Posh-ACME/the ACME server.
- **4b:** Rate limit hit -> the TUI recommends switching to Staging (UC-1.4).

## Technical notes
- PowerShell command: `New-PACertificate -Domain "example.com","www.example.com" -Plugin Cloudflare -PluginArgs $pArgs`
- The spinner is implemented with `Write-Host -NoNewline` and `[Console]::SetCursorPosition`.
