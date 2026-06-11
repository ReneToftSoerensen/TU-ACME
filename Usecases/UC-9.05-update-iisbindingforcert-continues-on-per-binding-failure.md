# UC-9.05 — Update-IISBindingForCert continues on per-binding failure

**Behavior:** The renewal-time helper `Update-IISBindingForCert` is the post-renewal half of the IIS thin-layer flow. Given the old and new thumbprints, it:

1. Imports the new cert PFX into `Cert:\LocalMachine\WebHosting` if it is not already there (UC-9.14).
2. Walks every HTTPS binding currently pinned to the old thumbprint and updates `certificateHash` to the new one via `Set-WebBinding` (UC-9.04, UC-9.02).
3. After every binding has been processed, attempts to delete the **old** cert from `Cert:\LocalMachine\WebHosting` (UC-9.16) so the store does not accumulate stale entries renewal after renewal.

Per-binding failure is non-fatal. If `Set-WebBinding` throws on one binding, the helper logs a warning (Event 2001) and continues to the next binding rather than terminating. Old-cert delete failure is likewise logged and swallowed (UC-9.03). The cert was already issued and the rebind pass already updated whatever bindings it could; the cost of aborting now is higher than the cost of an extra stale store entry.

Dry-run never reaches this helper: the renewal script (UC-8.08) only calls `Update-IISBindingForCert` for production renewals.

**Given** two HTTPS bindings whose `certificateHash` equals `$OldThumbprint`, and `Set-WebBinding` throws when invoked for the first one
**When** `Update-IISBindingForCert -OldThumbprint <old> -NewThumbprint <new>` runs
**Then** `Set-WebBinding` is invoked for both bindings (exactly twice in total), the function returns normally without re-throwing the inner exception, the old-cert delete is attempted exactly once, and a warning event is emitted for the failed binding

**Implementation:** `TU-ACME/Scripts/Posh-ACME-IIS-Plugin.ps1`
**Test:** `tests/Scripts/Posh-ACME-IIS-Plugin.Tests.ps1`
