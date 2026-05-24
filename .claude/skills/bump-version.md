---
name: bump-version
description: Use when the user asks to bump the module version ("bump version to X.Y.Z"). Updates every version literal in lockstep.
---

Update `ModuleVersion` in `TU-ACME/TU-ACME.psd1`, `Version` in the `$defaults` block of `TU-ACME/Private/Helpers/Get-TUACMEConfig.ps1`, the title literal in `TU-ACME/Public/Start-TUACME.ps1`, the test-mail body in `TU-ACME/Private/Automation/Invoke-SMTPConfig.ps1`, and the version lines in `README.md`, `INSTALL.md`, and `SMOKE-TEST.md`. Then run `git grep '<old-version>'` to catch any stragglers and update them too.
