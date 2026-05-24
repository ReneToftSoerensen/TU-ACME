---
name: new-private-function
description: Use when the user asks to add a private helper or new private function. Scaffolds the .ps1 file and a matching empty Pester test.
---

Create `TU-ACME/Private/<Domain>/<Verb-Noun>.ps1` with UTF-8 BOM, a `[CmdletBinding()]` attribute, and a `param()` skeleton. Then create the matching empty Pester file at `tests/Unit/<Domain>/<Verb-Noun>.Tests.ps1` (also UTF-8 BOM) with a `Describe` block named after the function so the UC traceability matrix can link it later.
