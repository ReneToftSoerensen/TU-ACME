#Requires -Version 5.1
<#
.SYNOPSIS
    Post-renewal plugin til automatisk opdatering af IIS HTTPS-bindings.
    Registreres med: Set-PAConfig -PostScript "<sti>\Posh-ACME-IIS-Plugin.ps1"

.NOTES
    Posh-ACME kalder scriptet med følgende parametre i $env:POSHACME_* eller direkte:
    - OldCertThumbprint / $OldThumbprint
    - NewCertPath       / $CertFile
    - NewCertThumbprint / $Thumbprint
#>

param(
    [string] $OldThumbprint,
    [string] $CertFile,
    [string] $Thumbprint
)

# Posh-ACME sender også via environment-variabler som fallback
if (-not $OldThumbprint) { $OldThumbprint = $env:POSHACME_OLD_CERT_THUMBPRINT }
if (-not $CertFile)      { $CertFile      = $env:POSHACME_CERT_FILE }
if (-not $Thumbprint)    { $Thumbprint    = $env:POSHACME_THUMBPRINT }

$logSource = 'TU-ACME'
$logName   = 'Application'

function Write-IISLog {
    param([int] $EventId, [string] $Message, [string] $EntryType = 'Information')
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($logSource)) {
            New-EventLog -LogName $logName -Source $logSource
        }
        Write-EventLog -LogName $logName -Source $logSource `
            -EventId $EventId -EntryType $EntryType -Message $Message
    } catch {}
}

# Intet gammelt thumbprint — intet at opdatere
if (-not $OldThumbprint) {
    Write-IISLog -EventId 1002 -Message 'TU-ACME IIS-plugin: Intet gammelt thumbprint. Springer over.'
    exit 0
}

try {
    Import-Module WebAdministration -ErrorAction Stop
} catch {
    Write-IISLog -EventId 3002 -Message "TU-ACME IIS-plugin: WebAdministration ikke tilgængeligt. $_" -EntryType Error
    exit 1
}

# Importer nyt certifikat til LocalMachine\My hvis CertFile er angivet
if ($CertFile -and (Test-Path $CertFile)) {
    try {
        Import-PfxCertificate -FilePath $CertFile `
            -CertStoreLocation 'Cert:\LocalMachine\My' -Exportable | Out-Null
    } catch {
        Write-IISLog -EventId 3002 `
            -Message "TU-ACME IIS-plugin: Fejl ved import af certifikat: $_" -EntryType Error
    }
}

# Find og opdater alle HTTPS-bindings med det gamle thumbprint
$bindings = @(Get-WebBinding -Protocol 'https' |
    Where-Object { $_.certificateHash -eq $OldThumbprint })

if ($bindings.Count -eq 0) {
    Write-IISLog -EventId 1002 `
        -Message "TU-ACME IIS-plugin: Ingen bindings matchede thumbprint $OldThumbprint."
    exit 0
}

foreach ($binding in $bindings) {
    $site = $binding.ItemXPath -replace ".*\[@name='(.+?)'\].*", '$1'
    try {
        $binding.certificateHash = $Thumbprint
        $binding | Set-WebBinding
        $msg = "IIS-binding opdateret: $site — gammelt thumbprint: $OldThumbprint — nyt: $Thumbprint"
        Write-IISLog -EventId 1002 -Message $msg
    } catch {
        $errMsg = "IIS-binding fejl: $site — $_"
        Write-IISLog -EventId 3002 -Message $errMsg -EntryType Error
        # Fortsæt med næste binding selvom én fejler
    }
}
