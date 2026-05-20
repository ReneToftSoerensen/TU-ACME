# UC-6.3: Import certificate directly into the Windows Certificate Store

**Category:** Export and Import  
**Priority:** High

## Goal
Install the certificate on the local Windows machine so it is ready for use in IIS or other Windows services.

## Actors
- System administrator (Admin)

## Preconditions
- TUI is running with administrator privileges (UC-0.1).
- The certificate has been ordered and is managed by Posh-ACME (UC-2.2).

## Main flow
1. The user selects a certificate from the overview and presses "Import to Windows Store".
2. The TUI lets the user choose the certificate store via a menu:
   ```
   Select certificate store:
   > Personal (My)        - Default for IIS and most services
     Web Hosting           - Storage optimized for many IIS certificates
   ```
3. The user confirms the selection.
4. The system imports the certificate into the `LocalMachine` store (not `CurrentUser`) together with the private key.
5. Success message is shown:
   ```
   [OK] Certificate imported into LocalMachine\My
   Thumbprint: A1B2C3D4E5F6...
   ```

## Postconditions
- The certificate is installed in the Windows Certificate Store along with the private key.
- IIS and other Windows services can now use the certificate via its thumbprint.

## Alternative flows
- **4a:** Certificate already installed (same thumbprint) -> Confirmation is shown, no error.
- **4b:** Error during import -> Precise error message from .NET/Windows.

## Technical notes
- PowerShell command: `Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation "Cert:\LocalMachine\My" -Password $securePassword`
- Web Hosting store: `Cert:\LocalMachine\WebHosting`
- The private key must be marked as exportable if the certificate is to be transferable elsewhere.
