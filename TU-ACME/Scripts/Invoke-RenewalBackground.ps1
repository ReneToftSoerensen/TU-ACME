#Requires -Version 5.1
<#
.SYNOPSIS
    Background script for automatic certificate renewal via Scheduled Task.
    Also performs the IIS post-renewal rebind because Posh-ACME v4 has no
    native post-script hook.

    Run with: powershell.exe -NonInteractive -WindowStyle Hidden -File "Invoke-RenewalBackground.ps1"
#>

$ErrorActionPreference = 'Stop'

$onWindows = if (Test-Path variable:IsWindows) { $IsWindows } else { $true }
if (-not $onWindows) {
    Write-Host 'Invoke-RenewalBackground.ps1 is designed for Windows Scheduled Tasks.' -ForegroundColor Yellow
    Write-Host 'Use cron + pwsh Submit-Renewal on Linux/macOS.' -ForegroundColor Gray
    exit 0
}

if (-not $env:ProgramData)  { $env:ProgramData  = '/tmp/TU-ACME' }
if (-not $env:COMPUTERNAME) { $env:COMPUTERNAME = [System.Net.Dns]::GetHostName() }

# Reuse the module's helpers + the IIS rebind function. All live in
# TU-ACME's tree next to this script.
$script:OnWindows = $true
$helpersDir = Join-Path $PSScriptRoot '..\Private\Helpers'
. (Join-Path $helpersDir 'Get-TUACMEConfig.ps1')
. (Join-Path $helpersDir 'Write-EventLogEntry.ps1')
. (Join-Path $helpersDir 'Send-TUACMEMail.ps1')
. (Join-Path $PSScriptRoot 'Posh-ACME-IIS-Plugin.ps1')   # defines Update-IISBindingForCert

function Send-ErrorMail {
    param([string] $Domain, [string] $ErrorMessage)

    $config = Get-TUACMEConfig
    if (-not $config -or -not $config.Email.SmtpServer) { return }

    $body = @"
Timestamp:    $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Server:       $env:COMPUTERNAME
Domain:       $Domain
Error type:   Certificate renewal failed
Error:        $ErrorMessage

Action required:
Check certificate status in TU-ACME or run:
  Submit-Renewal -Force -Domain "$Domain"

-- Sent automatically by TU-ACME --
"@

    Send-TUACMEMail -Subject "[TU-ACME] ERROR during certificate renewal - $Domain" -Body $body | Out-Null
}

function Get-CertThumbprintMap {
    # Returns a hashtable: MainDomain -> @{ Thumbprint=; PfxFile= }
    $map = @{}
    try {
        Get-PACertificate -List 2>$null | ForEach-Object {
            if ($_.AllSANs -and $_.Thumbprint) {
                $primary = @($_.AllSANs)[0]
                $map[$primary] = @{
                    Thumbprint = $_.Thumbprint
                    PfxFile    = $_.PfxFile
                }
            }
        }
    } catch {}
    return $map
}

try {
    Import-Module Posh-ACME -ErrorAction Stop
} catch {
    Write-EventLogEntry -EventId 3001 -EntryType Error `
        -Message "TU-ACME: Posh-ACME not available. $_"
    exit 1
}

# Snapshot thumbprints BEFORE the renewal so we can detect which certs
# got new thumbprints and rebind their IIS bindings afterwards.
$before = Get-CertThumbprintMap

try {
    $results = Submit-Renewal -AllAccounts

    if ($results) {
        foreach ($r in $results) {
            Write-EventLogEntry -EventId 1001 `
                -Message "Certificate renewed: $($r.MainDomain). New thumbprint: $($r.Thumbprint)"
        }
    } else {
        Write-EventLogEntry -EventId 1001 -Message 'TU-ACME: No certificates required renewal.'
    }
} catch {
    $errMsg = "$_"
    $domain = 'Unknown'

    try {
        $domain = (Get-PACertificate -List | Where-Object { $_.status -eq 'pending' } | Select-Object -First 1).MainDomain
    } catch {}

    Write-EventLogEntry -EventId 3001 -EntryType Error `
        -Message "TU-ACME: Certificate renewal failed for $domain. $_"
    Send-ErrorMail -Domain $domain -ErrorMessage $errMsg
    exit 1
}

# Post-renewal: rebind IIS for any cert whose thumbprint actually changed.
$after = Get-CertThumbprintMap

foreach ($domain in $after.Keys) {
    $newTp = $after[$domain].Thumbprint
    $oldTp = if ($before.ContainsKey($domain)) { $before[$domain].Thumbprint } else { '' }

    if ($oldTp -and $oldTp -ne $newTp) {
        Write-EventLogEntry -EventId 1002 `
            -Message "TU-ACME: Detected new thumbprint for $domain (old: $oldTp -> new: $newTp). Rebinding IIS..."
        try {
            Update-IISBindingForCert -OldThumbprint $oldTp -NewThumbprint $newTp -CertFile $after[$domain].PfxFile
        } catch {
            Write-EventLogEntry -EventId 3002 -EntryType Error `
                -Message "TU-ACME: IIS rebind failed for $domain - $_"
        }
    }
}
