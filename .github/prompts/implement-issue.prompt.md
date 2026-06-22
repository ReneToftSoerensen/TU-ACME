---
mode: agent
description: Implement a PoshTUI issue file end-to-end, following the repo instructions and Posh-ACME/IIS rules.
tools: ['codebase', 'search', 'editFiles', 'runCommands']
---

# Implement issue

Implement the issue described in ${input:issueFile:path to the ISSUE markdown, e.g. ISSUE-01-rewrite.md}.

## Before writing code
- Read the issue file in full, plus `.github/copilot-instructions.md` and every
  file under `.github/instructions/`.
- Restate the acceptance criteria as a short checklist and the file/module layout
  you will create. Note any ambiguity and your chosen resolution.

## While implementing
- Honor the Posh-ACME 4.x rules (`posh-acme.instructions.md`): `-AllOrders` not
  `-RenewAll`; `-Plugin` not `-DnsPlugin`; `Install-PACertificate -StoreName` for
  the cert store; `Set-PAAccount -UseAltPluginEncryption` for DNS accounts;
  date-field normalization; invalid-order handling; `Set-PAServer` arg shape.
- Honor IIS rules (`iis-bindings.instructions.md`): single thumbprint<->byte
  helper, SNI flag, commit once, idempotent edits, store alignment.
- Honor PowerShell style (`powershell.instructions.md`): approved verbs, no
  aliases, typed params, `[CmdletBinding(SupportsShouldProcess)]` on state
  changes, `Set-StrictMode`.
- Preserve the existing UX exactly (menus, the 6-step wizard, WACS-style
  filtering). Do not redesign prompts.
- Share binding/install helpers between the wizard and `PoshAcme-Renew.ps1`; do
  not duplicate them.

## Definition of done
- `Invoke-ScriptAnalyzer -Path ./src -Recurse` is clean.
- Pester tests added for new pure functions and passing (`Invoke-Pester ./tests`).
- Every acceptance-criteria box in the issue is satisfied; list them with status
  in your summary.
- No `-RenewAll` / `-DnsPlugin` anywhere; no duplicated rebind logic.
