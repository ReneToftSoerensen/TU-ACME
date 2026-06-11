# UC-7.02 — SMTP password persisted DPAPI-encrypted

**Behavior:** When the operator opts in to authentication, the SMTP password is collected as a `SecureString` via `Read-Host -AsSecureString`, encrypted with DPAPI (per-machine on Windows via `ConvertFrom-SecureString` without a key), and persisted to `%ProgramData%\TU-ACME\smtp-credentials.xml` via `Export-Clixml`.

**Given** an SMTP configuration session with `UseAuth = $true` and a known SecureString password
**When** the operator confirms the summary with `y`
**Then** `Read-Host -AsSecureString` collects the password and `ConvertFrom-SecureString` plus `Export-Clixml` are each invoked once to write `smtp-credentials.xml` under `$env:ProgramData\TU-ACME\`

**Implementation:** `TU-ACME/Private/Automation/Invoke-SMTPConfig.ps1`
**Test:** `tests/Unit/Automation/UC-7.02.Tests.ps1`
