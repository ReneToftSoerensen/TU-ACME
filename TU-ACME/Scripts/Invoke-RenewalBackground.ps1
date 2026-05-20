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

$configDir  = Join-Path $env:ProgramData 'TU-ACME'
$logSource  = 'TU-ACME'
$logName    = 'Application'

function Write-Log {
    param([int] $EventId, [string] $Message, [string] $EntryType = 'Information')
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($logSource)) {
            New-EventLog -LogName $logName -Source $logSource
        }
        Write-EventLog -LogName $logName -Source $logSource `
            -EventId $EventId -EntryType $EntryType -Message $Message
    } catch {}
}

function Get-Config {
    $configPath = Join-Path $configDir 'config.json'
    if (Test-Path $configPath) {
        return Get-Content -Path $configPath -Raw | ConvertFrom-Json
    }
    return $null
}

function Send-ErrorMail {
    param([string] $Domain, [string] $ErrorMessage)

    $config = Get-Config
    if (-not $config -or -not $config.Email.SmtpServer) { return }

    $credPath = Join-Path $configDir 'smtp-credentials.xml'
    $subject  = "[TU-ACME] ERROR during certificate renewal - $Domain"
    $body     = @"
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

    $mailParams = @{
        SmtpServer = $config.Email.SmtpServer
        Port       = $config.Email.SmtpPort
        From       = $config.Email.SenderAddress
        To         = $config.Email.RecipientAddress
        Subject    = $subject
        Body       = $body
        UseSsl     = $config.Email.UseSsl
    }

    if ($config.Email.UseAuth -and (Test-Path $credPath)) {
        try {
            $stored = Import-Clixml -Path $credPath
            $cred   = New-Object System.Management.Automation.PSCredential(
                $stored.Username, $stored.Password
            )
            $mailParams['Credential'] = $cred
        } catch {}
    }

    try {
        Send-MailMessage @mailParams
    } catch {}
}

# Import Posh-ACME
try {
    Import-Module Posh-ACME -ErrorAction Stop
} catch {
    Write-Log -EventId 3001 -Message "TU-ACME: Posh-ACME not available. $_" -EntryType Error
    exit 1
}

# Run renewal
try {
    $results = Submit-Renewal -AllAccounts

    if ($results) {
        foreach ($r in $results) {
            $msg = "Certificate renewed: $($r.MainDomain). New thumbprint: $($r.Thumbprint)"
            Write-Log -EventId 1001 -Message $msg
        }
    } else {
        Write-Log -EventId 1001 -Message 'TU-ACME: No certificates required renewal.'
    }
} catch {
    $errMsg = "$_"
    $domain = 'Unknown'

    try {
        $domain = (Get-PACertificate -List | Where-Object { $_.status -eq 'pending' } | Select-Object -First 1).MainDomain
    } catch {}

    Write-Log -EventId 3001 -Message "TU-ACME: Certificate renewal failed for $domain. $_" -EntryType Error
    Send-ErrorMail -Domain $domain -ErrorMessage $errMsg
    exit 1
}
