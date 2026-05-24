---
name: run-pester
description: Use when the user asks to run tests ("run tests", "run pester"). Invokes the Pester 5 test suite with the project's shared configuration.
---

Run `Invoke-Pester ./tests -Configuration (& .\tests\pester.config.ps1)` from the repo root. Optionally filter with `-Tag Unit`, `-Tag Integration`, or `-Tag Scripts` to scope to a single tier; the `LiveExternal` tag is excluded by default in the config.
