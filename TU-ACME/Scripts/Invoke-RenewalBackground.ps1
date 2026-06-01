<#
.SYNOPSIS
    Background renewal entry point invoked by the Posh-ACME-AutoRenewal
    scheduled task (runs as SYSTEM) and by the "Run renewal now
    (foreground)" entry in the Automation menu.
.DESCRIPTION
    Resolves the loaded TU-ACME module (importing it once if necessary,
    never -Force, because -Force tears down the running module instance
    and would wreck the in-flight TUI when invoked from the menu) and
    invokes the renewal body inside the module's own scope via
    & $module { ... }. That scope binding is what lets the body call
    module-private helpers (Write-EventLogEntry, Use-TUACMEProdAccount,
    Get-TUACMEConfig, Send-TUACMEMail) — a plain `& script.ps1` runs in
    a child of the global scope and would not see them.

    The body switches to the prod account, snapshots certificate
    thumbprints before and after Submit-Renewal (prod-only — never
    -AllAccounts, which would auto-renew dry-run certs under the staging
    account), emits Event 1001 for every cert whose thumbprint changed,
    and calls Update-IISBindingForCert when that helper is available. On
    fatal failure it writes Event 3001 and best-effort notifies via
    Send-TUACMEMail.

    Hashtables keyed by MainDomain (Posh-ACME's canonical cert
    identifier) rather than Subject — internal-CA certs can have an
    empty Subject field, which would collapse the snapshot onto a
    single key.
#>
[CmdletBinding()]
param(
    [switch] $Foreground
)

$ErrorActionPreference = 'Stop'

$module = Get-Module TU-ACME
if (-not $module) {
    Import-Module TU-ACME
    $module = Get-Module TU-ACME
}

& $module {
    param([bool] $Foreground)

    try {
        Use-TUACMEProdAccount

        $before = @{}
        Get-PACertificate -List | ForEach-Object {
            $before[$_.MainDomain] = $_.Thumbprint
        }

        # No certs at all → nothing for Submit-Renewal to do. Posh-ACME's
        # Submit-Renewal hard-throws "No order found for the specified
        # parameters" in this case (Stop-priority, not catchable by
        # -ErrorAction), and our outer catch would mis-report that as
        # Event 3001 with a "renewal FAILED" notification mail. Short-
        # circuit benignly with Event 1001 instead.
        if ($before.Count -eq 0) {
            Write-EventLogEntry -EventId 1001 -EntryType Information `
                -Message 'Renewal pass completed; no certs to renew.'
            return
        }

        try {
            Submit-Renewal -ErrorAction Continue
        } catch {
            # Defence-in-depth: if Submit-Renewal still throws "No order
            # found" through some other race (e.g. a cert was deleted
            # between the snapshot and the call), treat it as benign.
            # Anything else bubbles to the outer catch as a real failure.
            if ($_.Exception.Message -notmatch 'No order found') { throw }
        }

        $after   = @{}
        $renewed = @()
        Get-PACertificate -List | ForEach-Object {
            $after[$_.MainDomain] = $_.Thumbprint
            if ($before.ContainsKey($_.MainDomain) -and $before[$_.MainDomain] -ne $_.Thumbprint) {
                $renewed += $_
            }
        }

        foreach ($cert in $renewed) {
            Write-EventLogEntry -EventId 1001 -EntryType Information `
                -Message "Renewal: $($cert.MainDomain) ($($before[$cert.MainDomain]) -> $($cert.Thumbprint))"

            # IIS rebind hook (best-effort; parallel agent owns the rebind helper).
            if (Get-Command Update-IISBindingForCert -ErrorAction SilentlyContinue) {
                try {
                    Update-IISBindingForCert `
                        -OldThumbprint $before[$cert.MainDomain] `
                        -NewThumbprint $cert.Thumbprint
                    Write-EventLogEntry -EventId 1002 -EntryType Information `
                        -Message "IIS rebind: $($cert.MainDomain) updated to $($cert.Thumbprint)"
                } catch {
                    Write-EventLogEntry -EventId 2001 -EntryType Warning `
                        -Message "IIS rebind failed for $($cert.MainDomain): $($_.Exception.Message)"
                }
            }
        }

        if (-not $renewed) {
            Write-EventLogEntry -EventId 1001 -EntryType Information `
                -Message 'Renewal pass completed; no certs renewed.'
        }
    }
    catch {
        $err = $_

        # Diagnostic context for the failure mail (and the event log).
        # Each lookup is guarded so a probe failure can never mask the
        # original Submit-Renewal / order error.
        $fqdn = try {
            [System.Net.Dns]::GetHostEntry($env:COMPUTERNAME).HostName
        } catch { $env:COMPUTERNAME }

        $runAs = try {
            [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        } catch { $env:USERNAME }

        # Active ACME directory at the moment of failure. After
        # Use-TUACMEProdAccount this is the prod URL; under dry-run it
        # would be the staging URL. We surface whatever Posh-ACME
        # actually has selected so the recipient can tell which CA
        # the error came from.
        $acmeDir = try {
            $srv = Get-PAServer -ErrorAction SilentlyContinue
            if ($srv) { $srv.location } else { '<unknown>' }
        } catch { '<unknown>' }

        $body = @"
TU-ACME renewal FAILED

Host           : $fqdn
RunAs          : $runAs
ACME directory : $acmeDir
Time           : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')

Error          : $($err.Exception.Message)
Exception type : $($err.Exception.GetType().FullName)

PowerShell stack trace:
$($err.ScriptStackTrace)

.NET stack trace:
$($err.Exception.StackTrace)
"@

        Write-EventLogEntry -EventId 3001 -EntryType Error `
            -Message "Renewal job failed on $fqdn (as $runAs, ACME directory $acmeDir): $($err.Exception.Message)"
        # Best-effort: notify via mail if SMTP configured.
        try {
            $cfg = Get-TUACMEConfig
            if ($cfg.Email.SmtpServer -and (Get-Command Send-TUACMEMail -ErrorAction SilentlyContinue)) {
                Send-TUACMEMail -Subject "TU-ACME renewal FAILED on $fqdn" -Body $body | Out-Null
            }
        } catch {}
        if (-not $Foreground) { exit 1 }
        throw
    }
} ([bool]$Foreground)
