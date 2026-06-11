# UC-8.08 — Renewal script triggers IIS rebind when helper present

**Behavior:** For every cert that was renewed, the script checks whether `Update-IISBindingForCert` is resolvable via `Get-Command`. If so, it calls the helper with the old and new thumbprints and writes Event 1002 on success or Event 2001 on failure. If the helper is not present, the rebind step is skipped silently.

**Given** one cert's thumbprint changed and `Update-IISBindingForCert` is available in the session
**When** the renewal loop processes the renewed cert
**Then** `Update-IISBindingForCert -OldThumbprint <old> -NewThumbprint <new>` is called exactly once

**Implementation:** `TU-ACME/Scripts/Invoke-RenewalBackground.ps1`
**Test:** `tests/Scripts/Invoke-RenewalBackground.Tests.ps1`
