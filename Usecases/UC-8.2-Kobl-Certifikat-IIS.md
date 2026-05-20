# UC-8.2: Bind certificate to IIS endpoints manually via the TUI

**Category:** IIS Integration  
**Priority:** High

## Goal
Update one or more IIS HTTPS bindings with the latest certificate directly from the terminal.

## Actors
- System administrator (Admin)

## Preconditions
- TUI is running with administrator privileges (UC-0.1).
- A certificate has been selected in the overview (UC-4.1 / UC-4.3).
- An IIS scan is available (UC-8.1).

## Main flow
1. The user selects a certificate in the overview (UC-4.1) and presses "Assign to IIS".
2. The system shows the list of scanned IIS endpoints (UC-8.1).
3. The user marks the desired endpoints with the arrow keys and presses **Space** to toggle:
   ```
   Select IIS endpoints (Space = toggle, Enter = confirm):
   [x] Example-site     https *:443:
   [ ] Test-site         https *:8443:test
   ```
4. The user presses **Enter** to confirm.
5. The app imports the certificate into the Windows Certificate Store (UC-6.3).
6. The app updates the selected IIS bindings with the new thumbprint:
   ```powershell
   Set-WebBinding -Name "Example-site" -BindingInformation "*:443:" -PropertyName "certificateHash" -Value $newThumbprint
   ```
7. A success message is shown for each updated endpoint.

## Postconditions
- The selected IIS bindings now use the latest certificate.

## Alternative flows
- **4a:** No endpoints selected -> Aborted, no changes.
- **6a:** Error updating a binding -> Error message for the specific endpoint; other endpoints are still updated.

## Technical notes
- Requires `Import-Module WebAdministration` and `Set-WebBinding`.
- The certificate must be imported into `LocalMachine\My` or `LocalMachine\WebHosting` (UC-6.3) before the IIS binding is updated.
