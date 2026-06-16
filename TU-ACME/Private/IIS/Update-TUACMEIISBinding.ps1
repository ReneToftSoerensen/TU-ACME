function Update-TUACMEIISBinding {
    <#
    .SYNOPSIS
    Re-points IIS HTTPS bindings at a freshly issued certificate (UC-9.02).

    .DESCRIPTION
    Selects bindings either by the old certificate thumbprint (renewal path) or
    by a specific site + binding information (manual path), imports the new
    certificate into the IIS-canonical WebHosting store, then updates each
    matching binding's certificate hash. Per-binding failures are logged (event 2001) and skipped
    so a single binding never aborts the caller (UC-9.03). Never rebinds on a
    non-Windows host or when no IIS provider (WebAdministration on Windows
    PowerShell 5.1, IISAdministration on PowerShell 7) is available (issue #16).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NewThumbprint,

        # Posh-ACME certificate object, imported to WebHosting before rebinding.
        [Parameter(Mandatory = $true)]
        [object]$Certificate,

        # Renewal sweep: rebind every binding currently serving this thumbprint.
        [string]$OldThumbprint = '',

        # Manual rebind: target one specific binding by its unique site + binding
        # information. A host header is neither always present (HTTPS bindings
        # are commonly '*:443:' with no host) nor unique, so it is not used as a
        # selector.
        [string]$SiteName = '',

        [string]$BindingInformation = ''
    )

    $updated = @()
    $failed = @()

    if (-not (Test-TUACMEIsWindows)) {
        return [pscustomobject]@{ Updated = $updated; Failed = $failed }
    }
    $provider = Get-TUACMEIISProvider
    if ($null -eq $provider) {
        Write-Verbose 'No IIS provider (WebAdministration / IISAdministration) is available; skipping IIS rebind.'
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
    elseif (-not [string]::IsNullOrEmpty($BindingInformation)) {
        $targets = @($allBindings | Where-Object {
                $_.BindingInformation -eq $BindingInformation -and
                ([string]::IsNullOrEmpty($SiteName) -or $_.SiteName -eq $SiteName)
            })
    }

    if ($targets.Count -eq 0) {
        return [pscustomobject]@{ Updated = $updated; Failed = $failed }
    }

    # Import into both stores so the new thumbprint resolves regardless of which
    # store a binding currently references; this keeps each per-binding update
    # safe even if the certificateStoreName switch below fails (UC-9.03). IIS
    # treats WebHosting as canonical, but My is a valid fallback.
    $null = Import-TUACMECertificate -Certificate $Certificate -StoreName @('My', 'WebHosting')

    foreach ($binding in $targets) {
        try {
            if ($provider -eq 'IISAdministration') {
                # PowerShell 7 path: there is no Set-WebBinding cmdlet, so the
                # certificateHash + certificateStoreName are set via the
                # ServerManager and committed atomically (issue #16).
                Set-TUACMEIISBindingCertificate -SiteName $binding.SiteName -BindingInformation $binding.BindingInformation -Thumbprint $NewThumbprint -StoreName 'WebHosting'
            }
            else {
                # Update the hash first: the new cert lives in both stores, so the
                # binding serves it immediately under its existing store name. Only
                # then switch the store name to canonical WebHosting. A failed hash
                # update therefore never strands the binding on a store/thumbprint
                # pair that lacks the cert (UC-9.03).
                Set-WebBinding -Name $binding.SiteName -BindingInformation $binding.BindingInformation -PropertyName 'certificateHash' -Value $NewThumbprint -ErrorAction Stop
                Set-WebBinding -Name $binding.SiteName -BindingInformation $binding.BindingInformation -PropertyName 'certificateStoreName' -Value 'WebHosting' -ErrorAction Stop
            }

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
