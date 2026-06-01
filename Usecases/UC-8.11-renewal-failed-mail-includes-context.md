# UC-8.11 — Renewal FAILED mail body includes full diagnostic context

## Trigger

`Invoke-RenewalBackground.ps1` enters its outer `catch` because a real
renewal error escaped Submit-Renewal (or any other step inside the body).
The mail-notification branch fires because the operator has configured
SMTP via the Automation → SMTP menu.

## Behaviour

The mail subject is `TU-ACME renewal FAILED on <fqdn>` and the body is a
plain-text report with the following fixed top section, followed by the
exception details and both stack traces:

```
TU-ACME renewal FAILED

Host           : <fully-qualified host name>
RunAs          : <DOMAIN\user or NT AUTHORITY\SYSTEM>
ACME directory : <active Posh-ACME directory URL at the moment of failure>
Time           : yyyy-MM-dd HH:mm:ss <tz offset>

Error          : <exception message>
Exception type : <full .NET type name>

PowerShell stack trace:
<$_.ScriptStackTrace>

.NET stack trace:
<$_.Exception.StackTrace>
```

Event 3001 is enriched with the same triple (`host`, `runAs`, `ACME
directory`) so the event log can be triaged without opening the mail.

## Why

Renewal-failure mails previously contained only `$_.Exception.Message`.
On a multi-host fleet, a recipient seeing
`"No order found for the specified parameters."` had no way to tell
which host produced it, which user context the renewal ran under
(operator-foreground vs. SYSTEM scheduled task), or which ACME directory
was the source. The new body answers all three on the first scroll.

Every probe (`[System.Net.Dns]::GetHostEntry`,
`[WindowsIdentity]::GetCurrent`, `Get-PAServer`) is wrapped in its own
`try/catch` so a probe failure can never mask the original renewal
error — at worst a field falls back to `$env:COMPUTERNAME`,
`$env:USERNAME`, or `<unknown>`.

Both stack traces are emitted because they answer different questions:
`$_.ScriptStackTrace` shows the PowerShell call chain inside TU-ACME and
Posh-ACME (which `Submit-Renewal` overload, which order loop iteration),
and `$_.Exception.StackTrace` shows the .NET frames when the underlying
exception originated in a native call (e.g. a WinHttp / TLS error from
Posh-ACME's HTTP client).

## Pester

`tests/Scripts/Invoke-RenewalBackground.Tests.ps1` — case "UC-8.11:
renewal FAILED mail body includes host, RunAs, ACME directory, message,
and stack trace": mocks `Submit-Renewal` to `throw`, captures the
`Send-TUACMEMail -Subject -Body` arguments, and asserts the subject
matches `^TU-ACME renewal FAILED on \S+$` and the body contains
`Host:`, `RunAs:`, the mocked ACME directory URL, the exception
message, and a "stack trace" header.
