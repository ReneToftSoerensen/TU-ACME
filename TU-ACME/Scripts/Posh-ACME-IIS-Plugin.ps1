#Requires -Version 5.1
<#
.SYNOPSIS
    Update IIS HTTPS bindings that reference an old certificate thumbprint
    to use the new thumbprint of a just-renewed certificate.

    This is NOT a Posh-ACME post-renewal hook (Posh-ACME v4 has no such
    hook). It is a TU-ACME wrapper invoked from
    Invoke-RenewalBackground.ps1 after Submit-Renewal completes.

.DESCRIPTION
    Two modes:

    1. Dot-sourced (from Invoke-RenewalBackground.ps1):
         . .\Posh-ACME-IIS-Plugin.ps1
         Update-IISBindingForCert -OldThumbprint X -NewThumbprint Y -CertFile path.pfx

       Just defines Update-IISBindingForCert in the caller's scope.

    2. Run directly (manual testing):
         powershell.exe -File Posh-ACME-IIS-Plugin.ps1 `
             -OldThumbprint X -Thumbprint Y -CertFile path.pfx

       Parses the params and calls the function.

.NOTES
    Logs every binding update + failure to the Application event log
    via Write-EventLogEntry (EventId 1002 success, 3002 error).
#>

param(
    [string] $OldThumbprint,
    [string] $CertFile,
    [string] $Thumbprint
)

# Posh-ACME used to pass values via environment variables. Kept as a
# fallback for anyone who set up the env-var contract manually.
if (-not $OldThumbprint) { $OldThumbprint = $env:POSHACME_OLD_CERT_THUMBPRINT }
if (-not $CertFile)      { $CertFile      = $env:POSHACME_CERT_FILE }
if (-not $Thumbprint)    { $Thumbprint    = $env:POSHACME_THUMBPRINT }

# Reuse the module's event-log helper. Dot-sources cleanly on any OS
# (it's a function definition; the platform check is inside the helper
# itself).
if (-not (Get-Variable -Name OnWindows -Scope Script -ErrorAction SilentlyContinue)) {
    $script:OnWindows = if (Test-Path variable:IsWindows) { $IsWindows } else { $true }
}
. (Join-Path $PSScriptRoot '..\Private\Helpers\Write-EventLogEntry.ps1')

function Update-IISBindingForCert {
    <#
    .SYNOPSIS
        Find all IIS HTTPS bindings using $OldThumbprint, import the new
        cert (if a CertFile is supplied), and rebind them to $NewThumbprint.
        Per-binding errors are logged and do not stop the loop.
    #>
    # Not [Parameter(Mandatory)] — empty strings reach the guard below
    # so the function degrades silently when invoked with no thumbprint
    # (e.g. direct run with empty env-var fallback).
    param(
        [string] $OldThumbprint,
        [string] $NewThumbprint,
        [string] $CertFile
    )

    if (-not $OldThumbprint) {
        Write-EventLogEntry -EventId 1002 -Message 'TU-ACME IIS rebind: No old thumbprint. Skipping.'
        return
    }

    try {
        Import-Module WebAdministration -ErrorAction Stop
    } catch {
        Write-EventLogEntry -EventId 3002 -EntryType Error `
            -Message "TU-ACME IIS rebind: WebAdministration not available. $_"
        return
    }

    if ($CertFile -and (Test-Path $CertFile)) {
        try {
            Import-PfxCertificate -FilePath $CertFile `
                -CertStoreLocation 'Cert:\LocalMachine\My' -Exportable | Out-Null
        } catch {
            Write-EventLogEntry -EventId 3002 -EntryType Error `
                -Message "TU-ACME IIS rebind: Error importing certificate '$CertFile': $_"
        }
    }

    $bindings = @(Get-WebBinding -Protocol 'https' |
        Where-Object { $_.certificateHash -eq $OldThumbprint })

    if ($bindings.Count -eq 0) {
        Write-EventLogEntry -EventId 1002 `
            -Message "TU-ACME IIS rebind: No bindings matched thumbprint $OldThumbprint."
        return
    }

    foreach ($binding in $bindings) {
        $site = $binding.ItemXPath -replace ".*\[@name='(.+?)'\].*", '$1'
        try {
            $binding.certificateHash = $NewThumbprint
            $binding | Set-WebBinding
            Write-EventLogEntry -EventId 1002 `
                -Message "IIS binding updated: $site - old: $OldThumbprint - new: $NewThumbprint"
        } catch {
            Write-EventLogEntry -EventId 3002 -EntryType Error `
                -Message "IIS binding error: $site - $_"
        }
    }
}

# Direct invocation (not dot-source): platform-check, then run.
if ($MyInvocation.InvocationName -ne '.') {
    $onWindows = if (Test-Path variable:IsWindows) { $IsWindows } else { $true }
    if (-not $onWindows) {
        Write-Host 'Posh-ACME-IIS-Plugin.ps1 is only supported on Windows (requires IIS).' -ForegroundColor Yellow
        exit 0
    }
    Update-IISBindingForCert -OldThumbprint $OldThumbprint -NewThumbprint $Thumbprint -CertFile $CertFile
}
