#Requires -Version 5.1
<#
.SYNOPSIS
    Background script for automatic certificate renewal via Scheduled Task.
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

# Reuse the module's helpers instead of duplicating them.
# The script lives in TU-ACME/Scripts/ next to TU-ACME/Private/Helpers/.
$script:OnWindows = $true
$helpersDir = Join-Path $PSScriptRoot '..\Private\Helpers'
. (Join-Path $helpersDir 'Get-TUACMEConfig.ps1')
. (Join-Path $helpersDir 'Write-EventLogEntry.ps1')
. (Join-Path $helpersDir 'Send-TUACMEMail.ps1')

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

try {
    Import-Module Posh-ACME -ErrorAction Stop
} catch {
    Write-EventLogEntry -EventId 3001 -EntryType Error `
        -Message "TU-ACME: Posh-ACME not available. $_"
    exit 1
}

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
