# UC-5.04: Quick-Select Known Names (FQDN / Hostname / IIS Host Headers) as CN or SAN

## Narrative

As an **operator**, I want to **quick-select a certificate's names from a list
of names the machine already knows about — its FQDN, its short hostname, and the
host headers of its IIS bindings — instead of typing each one**, so that **I can
order a multi-name certificate faster and without transcription mistakes**.

## Narrative Detail

When ordering (or dry-running) a certificate, the order helper first gathers the
machine's known names via `Get-TUACMESystemNameCandidate`: the machine **FQDN**,
its **short hostname**, and any **IIS bound host headers**. The list is
de-duplicated and ordered FQDN first, then hostname, then IIS host headers, with
each entry labelled by its source.

The candidates are presented through the filterable multi-select menu
`Show-TUACMEMultiSelectMenu`:

- **Space** toggles a name on/off.
- **`/`** starts a case-insensitive substring filter to narrow long lists.
- **Enter** confirms the current selection.
- **Esc** cancels the quick-pick.

The FQDN row is pre-selected so the common single-Enter case picks the FQDN.

Selection outcomes:

- **One name picked** — that name is the CN and the only domain ordered.
- **Two or more names picked** — the operator chooses which name is the CN via
  the single-select `Show-TUACMEMenu`; the remaining names become SANs. The
  result is returned CN-first (`[string[]]`).
- **Esc, or Enter with nothing selected, or no candidates at all** — the helper
  falls through to the existing manual FQDN/SAN typing flow (UC-5.03), unchanged.
- If the CN prompt itself is cancelled (Esc) after a multi-select, the helper
  returns an empty array and the caller does nothing.

The resulting name array flows unchanged into
`Invoke-TUACMEOrderCertificate -Domain` (CN first, SANs after), so this UC adds
no new event IDs — ordering still logs 1003 on success and 3002 on failure via
that function. The quick-pick is shared by both the **"Order certificate"** and
**"Dry-run order (staging)"** handlers, because both call `Get-TUACMEOrderDomain`.

**Out of scope:** the "Add HTTPS to an IIS site" flow (UC-9.04) keeps its own
binding-driven CN/SAN prompts and is not changed by this UC.

## Acceptance Criteria

- [x] Candidate names are gathered via `Get-TUACMESystemNameCandidate` (machine
  FQDN + short hostname + IIS bound host headers), de-duplicated and ordered
  FQDN, hostname, then IIS host headers, each labelled by source
- [x] Candidates are presented in a filterable multi-select menu where Space
  toggles, `/` filters by substring, Enter confirms, and Esc cancels
- [x] Picking a single name returns that name as the CN-only order
- [x] Picking two or more names prompts for the CN via `Show-TUACMEMenu`; the
  rest are returned as SANs, CN first
- [x] Esc, an empty confirmed selection, or no candidates falls back to the
  manual FQDN/SAN typing flow
- [x] Cancelling the CN prompt after a multi-select returns an empty array
  ("do nothing")
- [x] The manual entry behaviour from UC-5.03 is unchanged (Enter accepts the
  default SAN, `-` skips it, any other value overrides, blank FQDN returns `@()`,
  single-label FQDN de-dupes)
- [x] Menu colours stay Cyan/DarkCyan and all titles are ≤79 characters
- [x] No new event IDs are introduced; ordering still logs 1003/3002 through
  `Invoke-TUACMEOrderCertificate`
- [x] Selected names are forwarded as `[string[]]`, CN first, into
  `Invoke-TUACMEOrderCertificate -Domain`

## Implementation Notes

- New helper `Get-TUACMEMachineName` (`TU-ACME/Private/Helpers`) resolves the
  machine FQDN and short hostname.
- New helper `Get-TUACMESystemNameCandidate` (`TU-ACME/Private/Helpers`) composes
  the candidate list from the machine names and the IIS bound host headers,
  de-duped and ordered FQDN → hostname → IIS, each tagged with a `Source` of
  `'FQDN'`, `'Hostname'`, or `'IIS'`; it returns `@()` when nothing is found and
  reuses `Get-TUACMEIISBinding` for the IIS host headers.
- New TUI control `Show-TUACMEMultiSelectMenu` (`TU-ACME/Private/UI`) provides the
  Space-toggle / `/`-filter / Enter-confirm / Esc-cancel multi-select; it returns
  the selected indices (`[int[]]`, possibly empty) or `$null` on Esc.
- Modified `Get-TUACMEOrderDomain` (`TU-ACME/Private/UI`) adds the quick-pick
  branch ahead of the manual `Read-Host` flow; it reuses `Show-TUACMEMenu` for
  the CN prompt and preserves its `[string[]]` CN-first return contract and the
  manual fallback.
- **No new event IDs.** This UC is purely a name-entry UX layer; all logging
  remains in `Invoke-TUACMEOrderCertificate` (1003 success, 3002 failure).

## Test Coverage

**Unit:** `tests/Unit/UI/Get-TUACMEOrderDomain.Tests.ps1` mocks
`Get-TUACMESystemNameCandidate`, `Show-TUACMEMultiSelectMenu`, `Show-TUACMEMenu`,
and `Read-Host`, and verifies: the manual fallback behaviour from UC-5.03 when
there are no candidates (Enter default SAN, `-` skip, typed override, single-label
de-dupe, blank FQDN → `@()`); a single quick-pick returns the picked name with no
`Read-Host` call; a multi-pick prompts for the CN and returns CN-first; Esc and an
empty confirmed selection both fall back to manual typing; and cancelling the CN
prompt returns `@()`. `Show-TUACMEMultiSelectMenu` itself is unit-tested in
`tests/Unit/UI/Show-TUACMEMultiSelectMenu.Tests.ps1`.

**Integration:** N/A (the candidate sources — machine name and IIS bindings — are
environment-specific; covered indirectly by the UC-5.03 order integration test).

**Scripts:** N/A.
