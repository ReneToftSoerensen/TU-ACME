# UC-9.12 — Test-IsFqdnHostname classifies hostnames

## Trigger

`Invoke-IISOrderFromBindings` (UC-9.11) decides which hostnames to flag
with `[WARN]` before dispatching an order.

## Behaviour

`Test-IsFqdnHostname -Hostname <string>` returns `$true` for FQDN-shaped
hostnames and `$false` otherwise. Rules:

| Input                              | Result |
|---|---|
| `www.fragt.dk`                     | true  |
| `acme01.lab.fragt.root.local`      | true  |
| `*.fragt.dk`  (leftmost wildcard)  | true  |
| `ACME01P` (single-label)           | false |
| `''` / whitespace / `$null`        | false |
| `192.168.1.10` (IPv4 literal)      | false |
| `bad_name.fragt.dk` (underscore)   | false |
| `sub.*.fragt.dk` (non-leftmost `*`)| false |
| `-bad.fragt.dk` / `bad-.fragt.dk`  | false |

## Why

Public ACME CAs reject single-label hostnames, IP literals, underscored
labels, and non-leftmost wildcards. Internal AD CS deployments are
typically more permissive — single-label names in particular are
often issued on purpose for legacy NetBIOS-style applications. The
helper expresses the public-CA acceptance rules so callers can flag
deviations as a warning without blocking; TU-ACME's internal-CA-only
posture means a `false` answer is advisory.

The helper never throws on null / empty / weird input — every reject
path falls through to `$false` and the caller can render an advisory.

## Pester

`tests/Unit/Helpers/Test-IsFqdnHostname.Tests.ps1` — nine cases
covering the table above.
