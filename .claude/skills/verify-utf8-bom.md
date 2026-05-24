---
name: verify-utf8-bom
description: Use when the user asks to check BOM, or as a pre-commit check on PowerShell files. Walks the tree and reports any file missing the UTF-8 BOM.
---

Walk every `*.ps1`, `*.psm1`, and `*.psd1` in the repo and verify the first three bytes are `EF BB BF`. Report any offenders by path; do not modify files automatically. The expected check is `head -c 3 <file> | od -An -tx1` → `ef bb bf`.
