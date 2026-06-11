# UC-6.09 — WebSelfHost coexists with IIS via HTTP.sys URL prefix routing

**Behavior:** An order placed with `Plugin = 'WebSelfHost'` does NOT stop, restart, or rebind IIS. The Posh-ACME plugin opens an HttpListener on the URL prefix `http://+:80/.well-known/acme-challenge/`, which is more specific than IIS's wildcard binding on port 80. HTTP.sys routes the more specific prefix to HttpListener, so the challenge file is served alongside a running IIS without any IIS state change.

**Given** IIS is running with at least one HTTP binding on port 80, and `Invoke-OrderCertificate` is called with `-ChallengeType 'http-01'` and the `WebSelfHost` plugin
**When** the order dispatches `New-PACertificate`
**Then** no IIS site is stopped, no IIS binding is removed or added, and `Get-WebSite`/`Stop-WebSite`/`Start-WebSite` are never invoked by the TU-ACME flow

**Implementation:** `TU-ACME/Private/Certificates/Invoke-OrderCertificate.ps1` (Posh-ACME's `WebSelfHost` plugin handles the HttpListener internally)
**Test:** `tests/Unit/Certificates/UC-6.09.Tests.ps1`
