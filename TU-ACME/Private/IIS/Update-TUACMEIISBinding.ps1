function Update-TUACMEIISBinding {
    <#
    .SYNOPSIS
    Re-points IIS HTTPS bindings at a freshly issued certificate (UC-9.02).

    .DESCRIPTION
    Selects bindings either by the old certificate thumbprint (renewal path) or
    by host header (manual / order path), imports the new certificate into the
    IIS-canonical WebHosting store, then updates each matching binding's
    certificate hash. Per-binding failures are logged (event 2001) and skipped
    so a single binding never aborts the caller (UC-9.03). Never rebinds on a
    non-Windows host or when WebAdministration is unavailable.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NewThumbprint,

        # Posh-ACME certificate object, imported to WebHosting before rebinding.
        [Parameter(Mandatory = $true)]
        [object]$Certificate,

        [string]$OldThumbprint = '',

        [string]$HostHeader = ''
    )

    $updated = @()
    $failed = @()

    if (-not (Test-TUACMEIsWindows)) {
        return [pscustomobject]@{ Updated = $updated; Failed = $failed }
    }
    if ($null -eq (Get-Command -Name 'Set-WebBinding' -ErrorAction SilentlyContinue)) {
        Write-Verbose 'WebAdministration is not available; skipping IIS rebind.'
        return [pscustomobject]@{ Updated = $updated; Failed = $failed }
    }

    # Discovery must never abort a renewal (UC-9.03): a failure here leaves IIS
    # untouched and the caller proceeds with the cert already issued.
    $allBindings = @()
    try {
        $allBindings = @(Get-TUACMEIISBinding | Where-Object { $_.Protocol -eq 'https' })
    }
    catch {
        Write-Verbose ('IIS binding discovery failed; skipping rebind: {0}' -f $_.Exception.Message)
        return [pscustomobject]@{ Updated = $updated; Failed = $failed }
    }

    $targets = @()
    if (-not [string]::IsNullOrEmpty($OldThumbprint)) {
        $targets = @($allBindings | Where-Object { $_.Thumbprint -eq $OldThumbprint })
    }
    elseif (-not [string]::IsNullOrEmpty($HostHeader)) {
        $targets = @($allBindings | Where-Object { $_.HostHeader -eq $HostHeader })
    }

    if ($targets.Count -eq 0) {
        return [pscustomobject]@{ Updated = $updated; Failed = $failed }
    }

    # IIS reads a binding's cert from the per-machine WebHosting store, so the
    # cert must live there before Set-WebBinding runs (UC-9.02).
    $null = Import-TUACMECertificate -Certificate $Certificate -StoreName 'WebHosting'

    foreach ($binding in $targets) {
        try {
            Set-WebBinding -Name $binding.SiteName -BindingInformation $binding.BindingInformation -PropertyName 'certificateStoreName' -Value 'WebHosting' -ErrorAction Stop
            Set-WebBinding -Name $binding.SiteName -BindingInformation $binding.BindingInformation -PropertyName 'certificateHash' -Value $NewThumbprint -ErrorAction Stop

            Write-TUACMEEventLog -EventId 1002 -EntryType Information -Message ('IIS binding {0} on site ''{1}'' rebound to thumbprint {2}.' -f $binding.BindingInformation, $binding.SiteName, $NewThumbprint)
            $updated += $binding
        }
        catch {
            Write-TUACMEEventLog -EventId 2001 -EntryType Warning -Message ('IIS rebind failed for binding {0} on site ''{1}'': {2}' -f $binding.BindingInformation, $binding.SiteName, $_.Exception.Message)
            $failed += [pscustomobject]@{
                SiteName           = $binding.SiteName
                BindingInformation = $binding.BindingInformation
                Error              = $_.Exception.Message
            }
        }
    }

    return [pscustomobject]@{ Updated = $updated; Failed = $failed }
}
