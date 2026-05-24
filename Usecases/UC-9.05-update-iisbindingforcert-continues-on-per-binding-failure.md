# UC-9.05 — Update-IISBindingForCert continues on per-binding failure

**Behavior:** The renewal-time helper `Update-IISBindingForCert` walks every HTTPS binding currently pinned to the old thumbprint. If `Set-WebBinding` throws on one binding, the helper logs a warning and continues to the next binding rather than terminating.

**Given** two HTTPS bindings whose `certificateHash` equals `$OldThumbprint`, and `Set-WebBinding` throws when invoked for the first one
**When** `Update-IISBindingForCert -OldThumbprint <old> -NewThumbprint <new>` runs
**Then** `Set-WebBinding` is invoked for both bindings (exactly twice in total) and the function returns normally without re-throwing the inner exception

**Implementation:** `TU-ACME/Scripts/Posh-ACME-IIS-Plugin.ps1`
**Test:** `tests/Scripts/Posh-ACME-IIS-Plugin.Tests.ps1`
