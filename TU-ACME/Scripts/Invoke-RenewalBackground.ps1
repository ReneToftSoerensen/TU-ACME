#Requires -Version 5.1
<#
.SYNOPSIS
    Baggrundsscript til automatisk certifikatfornyelse via Scheduled Task.
    Køres med: powershell.exe -NonInteractive -WindowStyle Hidden -File "Invoke-RenewalBackground.ps1"
#>

$ErrorActionPreference = 'Stop'
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
    $subject  = "[TU-ACME] FEJL ved certifikatfornyelse - $Domain"
    $body     = @"
Tidsstempel:  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Server:       $env:COMPUTERNAME
Domæne:       $Domain
Fejltype:     Certifikatfornyelse mislykkedes
Fejlbesked:   $ErrorMessage

Handling påkrævet:
Tjek certifikatstatus i TU-ACME eller kør:
  Submit-Renewal -Force -Domain "$Domain"

-- Sendt automatisk af TU-ACME --
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
    Write-Log -EventId 3001 -Message "TU-ACME: Posh-ACME ikke tilgængeligt. $_" -EntryType Error
    exit 1
}

# Kør fornyelse
try {
    $results = Submit-Renewal -AllAccounts

    if ($results) {
        foreach ($r in $results) {
            $msg = "Certifikat fornyet: $($r.MainDomain). Nyt thumbprint: $($r.Thumbprint)"
            Write-Log -EventId 1001 -Message $msg
        }
    } else {
        Write-Log -EventId 1001 -Message 'TU-ACME: Ingen certifikater krævede fornyelse.'
    }
} catch {
    $errMsg = "$_"
    $domain = 'Ukendt'

    try {
        $domain = (Get-PACertificate -List | Where-Object { $_.status -eq 'pending' } | Select-Object -First 1).MainDomain
    } catch {}

    Write-Log -EventId 3001 -Message "TU-ACME: Certifikatfornyelse fejlet for $domain. $_" -EntryType Error
    Send-ErrorMail -Domain $domain -ErrorMessage $errMsg
    exit 1
}
