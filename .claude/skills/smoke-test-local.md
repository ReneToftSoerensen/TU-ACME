---
name: smoke-test-local
description: Use when the user asks how to test TU-ACME locally or reports odd wizard/import behavior on their machine. Walks through the manual smoke test and its known gotchas.
---

Guide the user through a local smoke test, in this order:

1. **Fresh PowerShell window — mandatory.** Running the Pester suite imports `tests/Fixtures/PoshACME.Stubs.psm1` globally; in a contaminated session the wizard fails with "Stub <command> called without a Pester mock". A fresh window also clears any `TUACME_DATA_DIR` test override so config resolves to `%ProgramData%\TU-ACME\config.json`.
2. **Prerequisites**: `Install-Module Posh-ACME -Scope CurrentUser -Force` (one-time). Works on Windows PowerShell 5.1 and PS 7.
3. **Import smoke test**: `Import-Module .\TU-ACME\TU-ACME.psd1 -ErrorAction Stop; Get-Command -Module TU-ACME`. Expected: only the public cmdlets listed in the manifest; a missing config produces a *warning*, never an error (AC-A.1).
4. **Wizard**: `Start-TUACME` prompts for contact email and prod/staging directory URLs. URLs must start with `https://` (forward slashes) and must be full ACME *directory* endpoints, not bare hostnames. For safe end-to-end testing use Let's Encrypt staging: `https://acme-staging-v02.api.letsencrypt.org/directory`.
5. **Verify outcome**: `config.json` exists with both account ids filled; Event Log Application source `TU-ACME` has event 1010; `Get-PAServer` points at the production directory.

To reset and re-run first-run setup, delete `%ProgramData%\TU-ACME\config.json`.
