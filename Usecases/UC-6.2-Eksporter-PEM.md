# UC-6.2: Export certificate to PEM/Key/Cert files

**Category:** Export and Import  
**Priority:** Medium

## Goal
Export raw certificate files for Linux-based systems, NGINX, Apache, firewalls, or other systems that do not use the PFX format.

## Actors
- System administrator (Admin)

## Preconditions
- The certificate has been ordered and is managed by Posh-ACME (UC-2.2).

## Main flow
1. The user selects a certificate from the overview (UC-4.1 or UC-4.3).
2. The user selects "Export" -> "Export to PEM".
3. The TUI prompts for a destination folder:  
   `Save files in folder: C:\Certs\example\`
4. The system exports and saves three files:
   - `cert.crt` - The certificate itself (PEM format)
   - `cert.key` - The private key (PEM format)
   - `chain.crt` - The CA certificate chain (PEM format)
5. Success message is shown:
   ```
   [OK] Files saved in: C:\Certs\example\
     - cert.crt
     - cert.key
     - chain.crt
   ```

## Postconditions
- Three PEM files are saved in the specified folder, ready for transfer to the target system.

## Alternative flows
- **3a:** The folder does not exist -> The TUI asks whether it should be created.
- **4a:** Missing write permissions -> Error message with guidance.

## Technical notes
- Posh-ACME already saves certificate files in PEM format in its profile folder.
- Files can be copied directly from: `$env:LOCALAPPDATA\Posh-ACME\<server>\<account>\<domain>\`
- File names in Posh-ACME: `cert.cer`, `cert.key`, `chain.cer`, `fullchain.cer`
