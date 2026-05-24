<#
.SYNOPSIS
    Defines Update-IISBindingForCert. Dot-source from the renewal
    background script so SYSTEM has access at task-run time.
.DESCRIPTION
    Stand-alone script (not a function-defining module). Drops a
    single top-level function in the caller's scope that walks
    every HTTPS IIS binding currently pinned to $OldThumbprint and
    rebinds it to $NewThumbprint via Set-WebBinding. Continues on
    per-binding failures so a single broken site does not abort
    the entire post-renewal sweep.
#>

function Update-IISBindingForCert {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $OldThumbprint,
        [Parameter(Mandatory)][string] $NewThumbprint
    )

    Import-Module WebAdministration -ErrorAction Stop

    $bindings = Get-WebBinding -Protocol 'https' |
        Where-Object { $_.certificateHash -eq $OldThumbprint }

    if (-not $bindings) {
        Write-Verbose "No IIS bindings using thumbprint $OldThumbprint"
        return
    }

    foreach ($b in $bindings) {
        try {
            $siteName = ($b.ItemXPath -replace ".*@name='([^']+)'.*", '$1')
            Set-WebBinding -Name $siteName `
                -BindingInformation $b.bindingInformation `
                -PropertyName 'certificateHash' `
                -Value $NewThumbprint
        } catch {
            # Continue on per-binding failure; don't take down the whole rebind pass.
            Write-Warning "Rebind failed for $($b.bindingInformation): $($_.Exception.Message)"
        }
    }
}
