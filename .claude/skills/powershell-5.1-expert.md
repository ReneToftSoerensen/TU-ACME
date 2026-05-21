---
name: powershell-5.1-expert
description: Enforces strict compatibility with Windows PowerShell 5.1 and the full .NET Framework.
argument-hint: "[check|fix]"
---

## Activation triggers
- The user asks for PowerShell scripts, automation, or troubleshooting on Windows.
- The codebase contains `.ps1`, `.psm1`, or `.psd1` files.

## Critical syntax bans (PowerShell 7+ features that MUST NOT be used)
1. NO pipeline chain operators (`&&` or `||`). Use instead: `CmdletA; if ($?) { CmdletB }`.
2. NO ternary operators (`? :`) or null-coalescing (`??`, `?.`). Use classic `if/else`.
3. NO `-AsHashtable` switch on `ConvertFrom-Json` (returns a PSCustomObject in 5.1).
4. NO `-Parallel` switch on `ForEach-Object`.

## Scripting standards
- Always specify the encoding explicitly as `utf8` in `Out-File` and `Set-Content` (PS 5.1 otherwise defaults to UTF-16 LE).
- Always include `[CmdletBinding()]` and `param` validation.
- Implement defensive error handling with `try/catch` and support `-WhatIf` / `-Confirm` where state changes occur.
