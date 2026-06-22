<#
    Deploy.ps1 - SHARED install + binding helpers used by both the interactive
    wizard (Step 6) and the unattended renewal runner (ISSUE-02). Defined once
    here so interactive and unattended rebinds behave identically.
#>

function Install-TUACMECertificate {
    <#
        .SYNOPSIS
            Imports an issued/renewed certificate into the configured cert store.
            Uses Install-PACertificate (NOT New-PACertificate -Install, which
            targets LocalMachine\My) so the store is exactly $StoreName.
        .PARAMETER OrderName
            Posh-ACME order name to install the certificate for.
        .PARAMETER StoreName
            LocalMachine store name (default WebHosting). Single source of truth
            for issuance import, binding StoreName, and the UI label.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$OrderName,
        [string]$StoreName = 'WebHosting'
    )
    if (-not $PSCmdlet.ShouldProcess("$OrderName", "Install into LocalMachine\$StoreName")) { return }
    Get-PACertificate $OrderName |
        Install-PACertificate -StoreLocation 'LocalMachine' -StoreName $StoreName
}

function Update-IISCertificateBinding {
    <#
        .SYNOPSIS
            Re-points every IIS HTTPS binding that matches a renewed certificate
            to the new thumbprint. Matches by SAN/host-header first (robust and
            idempotent for headless runs), falling back to the old thumbprint.
            Returns a result object with Rebound / Failed counts.
        .PARAMETER Thumbprint
            New certificate thumbprint to bind to.
        .PARAMETER HostHeaders
            SANs / host headers to match HTTPS bindings on.
        .PARAMETER OldThumbprint
            Optional previous thumbprint; used as a fallback match.
        .PARAMETER StoreName
            Store the certificate was imported into (binding CertificateStore).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Thumbprint,
        [string[]]$HostHeaders = @(),
        [string]$OldThumbprint = '',
        [string]$StoreName = 'WebHosting'
    )

    $targets = [System.Collections.Generic.List[object]]::new()
    foreach ($h in $HostHeaders) {
        foreach ($b in @(Get-IISSslBindings | Where-Object { $_.HostHeader -ieq $h })) {
            $targets.Add($b)
        }
    }
    # Fallback: any binding still on the old thumbprint not already captured.
    if ($OldThumbprint) {
        foreach ($b in @(Get-IISBindingsByThumbprint -Thumbprint $OldThumbprint)) {
            if (-not ($targets | Where-Object {
                    $_.SiteName -eq $b.SiteName -and $_.BindingInformation -eq $b.BindingInformation })) {
                $targets.Add($b)
            }
        }
    }

    if (-not $PSCmdlet.ShouldProcess("$($targets.Count) binding(s)", "rebind -> $Thumbprint")) {
        return [pscustomobject]@{ Rebound = 0; Failed = 0; Targets = $targets.Count }
    }

    $rebound = 0
    $failed  = 0
    foreach ($b in $targets) {
        try {
            Set-IISBindingCertificate -SiteName $b.SiteName `
                -BindingInformation $b.BindingInformation `
                -Thumbprint $Thumbprint -StoreName $StoreName
            $rebound++
        } catch {
            Write-Err "Failed to rebind $($b.SiteName) / $($b.BindingInformation): $_"
            $failed++
        }
    }

    return [pscustomobject]@{ Rebound = $rebound; Failed = $failed; Targets = $targets.Count }
}

function Invoke-TUACMEPostDeployHook {
    <#
        .SYNOPSIS
            Invokes the optional user-supplied post-deploy hook (.ps1) for a cert,
            for non-IIS targets. Isolated: a hook failure is logged and never rolls
            back the cert or aborts other certs. Honors Dry-Run / What-If.
        .OUTPUTS
            $true on success (or when disabled/skipped), $false on hook failure.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][object]$Certificate,
        [string]$HookPath = $script:Config.PostDeployHook,
        [string]$StoreName = $script:Config.CertStore
    )
    if (-not $HookPath) { return $true }
    if (-not (Test-Path $HookPath)) {
        Write-Warn "PostDeployHook not found: $HookPath"
        Write-TUACMELog -Level WARN -Message "PostDeployHook not found: $HookPath"
        return $false
    }

    $thumb = $Certificate.Thumbprint
    $invocation = "& '$HookPath' -Certificate <cert> -Thumbprint '$thumb' -StoreName '$StoreName'"

    if ($script:DryRun) {
        Write-Warn 'DRY-RUN: post-deploy hook not invoked.'
        Write-Host "  $invocation" -ForegroundColor Gray
        return $true
    }
    if (-not $PSCmdlet.ShouldProcess($HookPath, 'Invoke post-deploy hook')) { return $true }

    try {
        if ($script:WhatIf) {
            & $HookPath -Certificate $Certificate -Thumbprint $thumb -StoreName $StoreName -WhatIf
        } else {
            & $HookPath -Certificate $Certificate -Thumbprint $thumb -StoreName $StoreName
        }
        Write-TUACMELog -Level INFO -Message "PostDeployHook ran for $thumb via $HookPath"
        return $true
    } catch {
        Write-Err "Post-deploy hook failed: $_"
        Write-TUACMELog -Level ERROR -Message "PostDeployHook failed for $thumb : $_"
        return $false
    }
}
