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

# Reuse the module's event-log helper instead of duplicating it.
$script:OnWindows = $true
. (Join-Path $PSScriptRoot '..\Private\Helpers\Write-EventLogEntry.ps1')

# No old thumbprint — nothing to update
if (-not $OldThumbprint) {
    Write-EventLogEntry -EventId 1002 -Message 'TU-ACME IIS plugin: No old thumbprint. Skipping.'
    exit 0
}

try {
    Import-Module WebAdministration -ErrorAction Stop
} catch {
    Write-EventLogEntry -EventId 3002 -EntryType Error `
        -Message "TU-ACME IIS plugin: WebAdministration not available. $_"
    exit 1
}

# Import new certificate to LocalMachine\My if CertFile is provided
if ($CertFile -and (Test-Path $CertFile)) {
    try {
        Import-PfxCertificate -FilePath $CertFile `
            -CertStoreLocation 'Cert:\LocalMachine\My' -Exportable | Out-Null
    } catch {
        Write-EventLogEntry -EventId 3002 -EntryType Error `
            -Message "TU-ACME IIS plugin: Error importing certificate: $_"
    }
}

# Find and update all HTTPS bindings that use the old thumbprint
$bindings = @(Get-WebBinding -Protocol 'https' |
    Where-Object { $_.certificateHash -eq $OldThumbprint })

if ($bindings.Count -eq 0) {
    Write-EventLogEntry -EventId 1002 `
        -Message "TU-ACME IIS plugin: No bindings matched thumbprint $OldThumbprint."
    exit 0
}

foreach ($binding in $bindings) {
    $site = $binding.ItemXPath -replace ".*\[@name='(.+?)'\].*", '$1'
    try {
        $binding.certificateHash = $Thumbprint
        $binding | Set-WebBinding
        Write-EventLogEntry -EventId 1002 `
            -Message "IIS binding updated: $site - old thumbprint: $OldThumbprint - new: $Thumbprint"
    } catch {
        Write-EventLogEntry -EventId 3002 -EntryType Error `
            -Message "IIS binding error: $site - $_"
    }
}
