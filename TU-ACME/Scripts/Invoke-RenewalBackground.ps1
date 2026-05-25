<#
.SYNOPSIS
    Background renewal entry point invoked by the Posh-ACME-AutoRenewal
    scheduled task (runs as SYSTEM).
.DESCRIPTION
    Imports TU-ACME, switches to the prod account, snapshots certificate
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

try {
    Import-Module TU-ACME -Force
    Use-TUACMEProdAccount

    $before = @{}
    Get-PACertificate -List | ForEach-Object {
        $before[$_.MainDomain] = $_.Thumbprint
    }

    Submit-Renewal -ErrorAction Continue

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
    Write-EventLogEntry -EventId 3001 -EntryType Error `
        -Message "Renewal job failed: $($_.Exception.Message)"
    # Best-effort: notify via mail if SMTP configured.
    try {
        $cfg = Get-TUACMEConfig
        if ($cfg.Email.SmtpServer -and (Get-Command Send-TUACMEMail -ErrorAction SilentlyContinue)) {
            Send-TUACMEMail -Subject 'TU-ACME renewal FAILED' -Body $_.Exception.Message
        }
    } catch {}
    if (-not $Foreground) { exit 1 }
    throw
}
