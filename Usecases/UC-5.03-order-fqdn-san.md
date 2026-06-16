# UC-5.03: Order Certificate (FQDN as CN with Short Hostname SAN)

## Narrative

As an **operator**, I want to **order one certificate that covers a machine's
FQDN as the CN and its short hostname as a Subject Alternative Name**, so that
**clients reaching the host by either its fully-qualified name or its short
NetBIOS-style name validate against a single certificate**.

## Narrative Detail

When ordering for a domain-joined server such as `df-bpxt4s2-ws.fragt.root.local`,
operators frequently also need the short name `DF-BPXT4S2-WS` to validate (for
example, intranet bookmarks or legacy clients that connect by short name). Rather
than issuing two certificates, the order helper now accepts multiple names and
issues a single certificate with:

- the **FQDN** as the CN / primary domain (the first `-Domain` element), and
- the **short hostname** as a SAN (the second `-Domain` element).

The menu prompts for the FQDN, then proposes the first DNS label of that FQDN as
the default short-hostname SAN. The SAN prompt convention is:

- **Enter** — accept the proposed default short hostname as the SAN.
- **`-`** — skip the SAN entirely and order a single-name (FQDN-only) certificate.
- **any other value** — override the default with the typed short hostname.

If the FQDN is left blank the menu does nothing (unchanged from UC-5.01). If the
proposed/typed short name equals the FQDN (for example, a single-label FQDN), the
order de-dupes to a single-name certificate so the same name is never requested
twice.

## Internal CA Note

A single-label SAN (a host name with no dot, such as `DF-BPXT4S2-WS`) is only
issuable by an **internal CA**. Public CAs reject single-label names because they
are not globally unique and cannot be validated against a registered domain.
TU-ACME targets an internal ACME-capable CA per SPEC, so single-label short
hostnames are a supported and expected use case here.

## Acceptance Criteria

- [x] `Invoke-TUACMEOrderCertificate -Domain` accepts `[string[]]` (CN first, SANs after)
- [x] The full array is forwarded to `New-PACertificate -Domain` (MainDomain = first entry, rest = SANs)
- [x] The returned object's `.Domain` is the primary FQDN as a scalar string
- [x] Event 1003 (success) and 3002 (failure) messages reference the primary FQDN string
- [x] The menu prompts for the FQDN, then offers the first DNS label as the default SAN
- [x] Enter accepts the default SAN; `-` skips it; any other value overrides it
- [x] The short hostname is de-duplicated when it equals the FQDN
- [x] The success message reports the ordered primary and, when present, the included SAN
- [x] Single-string callers (UC-5.01 / UC-5.02) keep working unchanged
- [x] The dry-run path forwards the full name array through `Invoke-TUACMEDryRun` without flattening

## Implementation Notes

- Function: `Invoke-TUACMEOrderCertificate` (`-Domain` is now `[string[]]`, still Mandatory).
  The first element is the CN; subsequent elements are SANs. `New-PACertificate`
  already treats the first `-Domain` entry as MainDomain and the rest as SANs, so
  the array is forwarded as-is.
- `.Domain` on the return object and the 1003/3002 event messages use
  `$Domain[0]` (a scalar) so existing single-name callers and tests are unaffected.
- The dry-run path builds its `-ArgumentList` explicitly (via `ArrayList`) so the
  name array is preserved as a single positional argument; a bare `@(...)` list
  would flatten the SAN entries into separate positional arguments to the order
  scriptblock.
- Menu prompting lives in the private helper `Get-TUACMEOrderDomain`, shared by
  both the "Order certificate" and "Dry-run order (staging)" handlers.
- This is the shared multi-name foundation also used by #17.

## Test Coverage

**Unit:** Order with `@('df-bpxt4s2-ws.fragt.root.local','DF-BPXT4S2-WS')` and
assert `New-PACertificate` is invoked with `$Domain -contains` both names; assert
`.Domain` equals the primary FQDN scalar and event 1003 references it. A dry-run
case asserts both names survive the staging wrapper.

**Integration:** Order a multi-name cert against a real staging directory; verify
both the FQDN and the short hostname appear on the issued certificate.

**Scripts:** N/A
