# UC-6.1: Export certificate to a PFX file

**Category:** Export and Import  
**Priority:** Medium

## Goal
Save the certificate as a password-protected PFX file for use on other systems (e.g. other Windows servers, load balancers, firewalls).

## Actors
- System administrator (Admin)

## Preconditions
- The certificate has been ordered and is managed by Posh-ACME (UC-2.2).

## Main flow
1. The user selects a certificate from the overview (UC-4.1 or UC-4.3).
2. The user selects "Export" -> "Export to PFX".
3. The TUI prompts for a destination path:  
   `Save PFX as (full path): C:\Certs\example.pfx`
4. The TUI prompts for a password for the PFX (input is masked, UC-3.2):  
   `PFX password: ****`  
   `Confirm password: ****`
5. The system generates the PFX file via Posh-ACME.
6. Success message: `PFX saved: C:\Certs\example.pfx`

## Postconditions
- A password-protected PFX file is saved to the specified path.

## Alternative flows
- **4a:** Passwords do not match -> Error message and the user is asked to try again.
- **5a:** Missing write permissions to the destination folder -> Error message with guidance.

## Technical notes
- Posh-ACME saves the PFX file via `Export-PfxCertificate` or `openssl` depending on the certificate type.
- Alternatively: `[System.Security.Cryptography.X509Certificates.X509Certificate2]::Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $password)`
