<#
    Start-TUACME - public entry point. Launches the interactive menu loop.
#>

function Start-TUACME {
    <#
        .SYNOPSIS
            Launches the TU-ACME interactive terminal UI.
        .PARAMETER DryRun
            Print equivalent commands and make no changes.
        .PARAMETER WhatIf
            Forward -WhatIf to ShouldProcess-aware cmdlets where supported.
        .EXAMPLE
            Start-TUACME
        .EXAMPLE
            Start-TUACME -DryRun
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '',
        Justification = 'Menu launcher; -WhatIf is forwarded to ShouldProcess-aware cmdlets downstream.')]
    param(
        [switch]$DryRun
    )

    $script:DryRun = [bool]$DryRun
    $script:WhatIf = [bool]$WhatIfPreference
    if ($PSBoundParameters.ContainsKey('WhatIf')) { $script:WhatIf = [bool]$PSBoundParameters['WhatIf'] }
    if ($script:WhatIf) { $WhatIfPreference = $true }

    # Prerequisites + shared state.
    Assert-TUACMEElevated
    Assert-TUACMEModule
    Initialize-TUACMEHome
    Import-TUACMEConfig

    try {
        Show-MainMenu
    } finally {
        Save-TUACMEConfig
        Clear-Host
        Write-Host 'Goodbye.' -ForegroundColor Cyan
    }
}

function Show-MainMenu {
    while ($true) {
        Show-Banner
        Write-Sep 'Main menu'
        Write-Host ''
        Write-Host '  N: Create certificate (full options)'              -ForegroundColor White
        Write-Host '  M: Manage renewals (view / force-renew / renew all / delete)' -ForegroundColor White
        Write-Host '  B: Browse IIS bindings'                            -ForegroundColor White
        Write-Host '  S: Manage ACME accounts'                           -ForegroundColor White
        Write-Host '  T: Manage scheduled renewal tasks'                 -ForegroundColor White
        Write-Host ''
        if ($script:DryRun) { Write-Host '  (Dry-Run mode: no changes will be made)' -ForegroundColor Green }
        if ($script:WhatIf) { Write-Host '  (What-If mode: -WhatIf forwarded where supported)' -ForegroundColor Green }
        Write-Host '  Q: Quit' -ForegroundColor White
        Write-Host ''
        Write-Sep

        $key = Read-MenuChoice -Prompt 'Choice' -ValidKeys @('N', 'M', 'B', 'S', 'T', 'Q')
        try {
            switch ($key) {
                'N' { Invoke-NewCertificate }
                'M' { Invoke-ManageRenewals }
                'B' { Invoke-BrowseIISBindings }
                'S' { Invoke-SelectAccount }
                'T' { Invoke-ManageScheduledTasks }
                'Q' { return }
            }
        } catch {
            Write-Err "Unhandled error: $($_.Exception.Message)"
            Wait-UI
        }
    }
}
