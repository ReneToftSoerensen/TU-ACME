# UC-5.04: Quick Selection of Known Names as CN or SAN

## Narrative

As an **operator**, I want to **quickly pick the machine FQDN, the short
hostname, and IIS bound host headers from a pre-populated list** when ordering a
certificate, so that **I can assign well-known names as the CN or as SANs without
retyping them and without introducing typos** (issue #21).

## Narrative Detail

The most common certificate covers names that already exist on the system. Rather
than forcing the operator to type each one, the order workflow now offers a
quick-pick list built from:

- **FQDN** — the fully qualified domain name of the machine.
- **Hostname** — the short / NetBIOS-style hostname of the machine.
- **IIS bound host headers** — every host header currently bound in IIS site
  bindings on the server.

These candidates are gathered by the private helper `Get-TUACMEKnownName`, which
de-duplicates them case-insensitively and tags each one with its source. The
order helper `Get-TUACMEOrderDomain` then:

1. Presents the candidates (plus an **Enter a name manually...** escape hatch) so
   the operator can choose the **CN** with a single keypress, and
2. Repeatedly offers the remaining candidates so the operator can add zero or
   more **SANs**, finishing with **Done** or **Esc**. A name that has already
   been selected (including the CN) is hidden so it is never offered twice.

When no known names can be resolved (for example, a non-Windows host with no IIS
and no resolvable DNS name), the helper falls back to the typed convention from
UC-5.03: read the FQDN, then offer a short-hostname SAN defaulted to the first
DNS label (Enter accepts, `-` skips, any other value overrides).

The result is the same `[string[]]` shape consumed by
`Invoke-TUACMEOrderCertificate -Domain` (CN first, SANs after), so the order and
dry-run dispatch are unchanged.

## Acceptance Criteria

- [x] `Get-TUACMEKnownName` returns the FQDN, short hostname, and IIS bound host
  headers as `{ Name, Source }` candidates, in that order
- [x] Candidates are de-duplicated case-insensitively across all sources
- [x] Empty host headers (HTTP bindings with no host header) are skipped
- [x] `Get-TUACMEOrderDomain` offers the candidates as a CN pick-list with a
  manual-entry option, and cancels the order on Esc
- [x] `Get-TUACMEOrderDomain` offers the remaining candidates as a repeatable SAN
  pick-list, hiding already-selected names, finishing on Done or Esc
- [x] A manually typed SAN that duplicates an already-selected name is ignored
- [x] With no known names, the typed default short-hostname SAN convention
  (UC-5.03) is preserved unchanged
- [x] The returned array is `[string[]]` with the CN first and SANs after, ready
  for `Invoke-TUACMEOrderCertificate -Domain`

## Implementation Notes

- New helper: `Get-TUACMELocalMachineName` (`Private/Helpers`) resolves the short
  hostname and FQDN via `[System.Net.Dns]`, returning an empty FQDN when the
  machine is not domain-joined or only a single-label name resolves. Acting as a
  single mock seam keeps `Get-TUACMEKnownName` deterministic in unit tests.
- New helper: `Get-TUACMEKnownName` (`Private/UI`) composes the candidates from
  `Get-TUACMELocalMachineName` and `Get-TUACMEIISBinding` (which already returns
  an empty list off-Windows or when no IIS provider is present).
- `Get-TUACMEOrderDomain` uses `Show-TUACMEMenu` for the CN and SAN pick-lists,
  staying within the locked Cyan/DarkCyan palette and the 79-char title cap.
- This builds on the multi-name foundation from UC-5.03 (#17).

## Test Coverage

**Unit:** `Get-TUACMEKnownName` ordering, de-dupe, empty-header and no-FQDN cases
(mocking `Get-TUACMELocalMachineName` and `Get-TUACMEIISBinding`).
`Get-TUACMEOrderDomain` CN pick, multi-SAN pick, manual entry, duplicate
rejection, Esc cancel, and the no-known-names typed fallback (mocking
`Get-TUACMEKnownName`, `Show-TUACMEMenu`, and `Read-Host`).

**Integration:** N/A (interactive UI helper).

**Scripts:** N/A
