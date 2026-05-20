# UC-4.3: Show detailed information about a selected certificate

**Category:** Dashboard  
**Priority:** Medium

## Goal
View extended details for a specific certificate without leaving the TUI.

## Actors
- System administrator (Admin)
- Monitor/Technician (ReadOnly)

## Preconditions
- The dashboard with the certificate list is displayed (UC-4.1).

## Main flow
1. The user navigates up/down in the table with the arrow keys.
2. The highlighted certificate is emphasized (e.g. inverted color).
3. The user presses **Enter**.
4. A detail box opens in the TUI and shows:
   ```
   ===== Certificate details =====
   Domain:           example.com
   SAN:              www.example.com, mail.example.com
   Issuer:           Let's Encrypt
   Issued:           2026-05-18
   Expires:          2026-08-18
   Thumbprint:       A1B2C3D4E5F6...
   Path (certificate): C:\...\cert.cer
   Path (key):       C:\...\cert.key
   ACME account:     admin@example.com
   Latest renewal:   2026-05-18 03:01:42
   ==============================
   [E] Export  [I] Import to Store  [ESC] Back
   ```
5. The user presses ESC or Q to return to the list.

## Postconditions
- The user has viewed detailed information for the selected certificate.

## Alternative flows
- From the detail view the user can start UC-6.1, UC-6.2, or UC-6.3 directly.

## Technical notes
- PowerShell command: `Get-PACertificate -MainDomain "example.com"`
- The thumbprint is retrieved via: `(Get-Item "Cert:\LocalMachine\My\<thumbprint>").Thumbprint`
