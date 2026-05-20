# UC-4.1: Show interactive table of certificates (color-coded)

**Category:** Dashboard  
**Priority:** High

## Goal
Provide a quick, color-coded overview of all certificates managed by Posh-ACME.

## Actors
- System administrator (Admin)
- Monitor/Technician (ReadOnly)

## Preconditions
- Posh-ACME is installed. Zero or more certificates may exist.

## Main flow
1. The TUI loads certificates via `Get-PACertificate`.
2. The certificates are presented in a table with columns:
   ```
   Domain              Expiry date    Days left      Status
   ----------------------------------------------------------------
   example.com         2026-08-18     92             [OK]
   test.com            2026-06-02     15             [EXPIRES SOON]
   old.com             2026-05-10     -8             [EXPIRED]
   ```
3. Color coding based on days remaining:
   - **> 30 days:** Green text
   - **<= 30 days:** Yellow text
   - **Expired (< 0 days):** Red text (optionally blinking)
4. The table is refreshed on every visit to the dashboard.

## Postconditions
- The user has an overview of the status of all certificates.

## Alternative flows
- **1a:** No certificates found -> message: `No certificates. Order your first certificate (UC-2.1).`

## Technical notes
- PowerShell command: `Get-PACertificate -List`
- Colors are set with `Write-Host -ForegroundColor Green/Yellow/Red`
- Days are calculated as: `($cert.NotAfter - (Get-Date)).Days`
