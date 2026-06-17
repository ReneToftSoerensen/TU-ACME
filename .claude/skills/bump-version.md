---
name: bump-version
description: Use when the user asks to bump the module version ("bump version to X.Y.Z"). Updates every version literal in lockstep.
---

Update every version literal in lockstep:

- `ModuleVersion` in `TU-ACME/TU-ACME.psd1` — the source of truth.
- The version assertion in `tests/Unit/TU-ACME.Module.Tests.ps1` (the `Should -Be ([version]'X.Y.Z')` line) so the manifest test stays green.

The menu title in `TU-ACME/Public/Start-TUACME.ps1` reads the version from the loaded module at runtime (`$module.Version.ToString()`), so there is no literal to change there.

After editing, run `git grep '<old-version>'` to catch any straggler literals (for example a version line later added to `README.md`) and update them too, then re-run the unit suite to confirm the bump is consistent.
