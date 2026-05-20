# UC-2.1: Enter domain name and alternative names (SAN)

**Category:** Certificate ordering  
**Priority:** High

## Goal
Collect the domain information for the new certificate without the risk of syntax errors.

## Actors
- System administrator (Admin)

## Preconditions
- An active ACME account is configured (UC-1.1 / UC-1.2).

## Main flow
1. The user selects "Order new certificate" from the main menu.
2. The TUI prompts for the **Primary domain name (Common Name)**:  
   `Primary domain: _` (e.g. `example.com`)
3. The TUI prompts for **Alternative names (SAN)** (optional):  
   `Alternative names (comma-separated, press Enter to skip): _`  
   (e.g. `www.example.com, mail.example.com`)
4. The system validates the input:
   - The primary domain must not be empty.
   - All domains are validated against RFC-compliant domain syntax (regex).
   - Any whitespace errors in the SAN list are trimmed automatically.
5. On valid input, a summary view is shown with all domains before confirmation.

## Postconditions
- Domain names are validated and ready for certificate ordering (UC-2.2).

## Alternative flows
- **4a:** Invalid domain format -> red error message and the user is asked to correct the input.
- **4b:** Wildcard domain (e.g. `*.example.com`) -> accepted, but DNS validation is required.

## Technical notes
- Domain validation regex: `^(\*\.)?([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$`
