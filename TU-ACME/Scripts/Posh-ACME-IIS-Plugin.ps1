#Requires -Version 5.1
<#
.SYNOPSIS
    Post-renewal plugin for automatic update of IIS HTTPS bindings.
    Register with: Set-PAConfig -PostScript "<path>\Posh-ACME-IIS-Plugin.ps1"

.NOTES
    Posh-ACME calls the script with the following parameters in $env:POSHACME_* or directly:
    - OldCertThumbprint / $OldThumbprint
    - NewCertPath       / $CertFile
    - NewCertThumbprint / $Thumbprint
#>

param(
    [string] $OldThumbprint,
    [string] $CertFile,
    [string] $Thumbprint
)

# Posh-ACME also passes values via environment variables as a fallback
if (-not $OldThumbprint) { $OldThumbprint = $env:POSHACME_OLD_CERT_THUMBPRINT }
if (-not $CertFile)      { $CertFile      = $env:POSHACME_CERT_FILE }
if (-not $Thumbprint)    { $Thumbprint    = $env:POSHACME_THUMBPRINT }

$onWindows = if (Test-Path variable:IsWindows) { $IsWindows } else { $true }
if (-not $onWindows) {
    Write-Host 'Posh-ACME-IIS-Plugin.ps1 is only supported on Windows (requires IIS).' -ForegroundColor Yellow
    exit 0
}

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

# No old thumbprint — nothing to update
if (-not $OldThumbprint) {
    Write-IISLog -EventId 1002 -Message 'TU-ACME IIS plugin: No old thumbprint. Skipping.'
    exit 0
}

try {
    Import-Module WebAdministration -ErrorAction Stop
} catch {
    Write-IISLog -EventId 3002 -Message "TU-ACME IIS plugin: WebAdministration not available. $_" -EntryType Error
    exit 1
}

# Import new certificate to LocalMachine\My if CertFile is provided
if ($CertFile -and (Test-Path $CertFile)) {
    try {
        Import-PfxCertificate -FilePath $CertFile `
            -CertStoreLocation 'Cert:\LocalMachine\My' -Exportable | Out-Null
    } catch {
        Write-IISLog -EventId 3002 `
            -Message "TU-ACME IIS plugin: Error importing certificate: $_" -EntryType Error
    }
}

# Find and update all HTTPS bindings that use the old thumbprint
$bindings = @(Get-WebBinding -Protocol 'https' |
    Where-Object { $_.certificateHash -eq $OldThumbprint })

if ($bindings.Count -eq 0) {
    Write-IISLog -EventId 1002 `
        -Message "TU-ACME IIS plugin: No bindings matched thumbprint $OldThumbprint."
    exit 0
}

foreach ($binding in $bindings) {
    $site = $binding.ItemXPath -replace ".*\[@name='(.+?)'\].*", '$1'
    try {
        $binding.certificateHash = $Thumbprint
        $binding | Set-WebBinding
        $msg = "IIS binding updated: $site — old thumbprint: $OldThumbprint — new: $Thumbprint"
        Write-IISLog -EventId 1002 -Message $msg
    } catch {
        $errMsg = "IIS binding error: $site — $_"
        Write-IISLog -EventId 3002 -Message $errMsg -EntryType Error
        # Continue with the next binding even if one fails
    }
}
