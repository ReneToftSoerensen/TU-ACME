---
name: add-use-case
description: Use when the user asks to add a use case ("add a use case for X", "new UC"). Scaffolds the UC file and updates the traceability matrix.
---

Scaffold a new `Usecases/UC-<d>.<nn>-<slug>.md` from the atomic template: ID, one-sentence behavior, one Given/When/Then, mapped Pester test path, mapped implementation file. Then append a row to `tests/UC-Traceability.md` linking the UC to its implementation file and test file.
