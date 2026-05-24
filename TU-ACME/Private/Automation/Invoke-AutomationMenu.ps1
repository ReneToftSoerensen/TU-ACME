function Invoke-AutomationMenu {
    <#
    .SYNOPSIS
        Automation sub-menu — SMTP, scheduled task, and ad-hoc renewal.
    .DESCRIPTION
        Renders a Show-Menu loop with the three automation entry points.
        The SMTP configurator is owned by a parallel agent; we resolve
        it at runtime via Get-Command so this file does not hard-fail
        when that function has not yet been wired up.
    #>
    [CmdletBinding()]
    param()

    $title   = 'Automation'
    $options = @(
        '1. Configure SMTP for notifications',
        '2. Install scheduled renewal task',
        '3. Run renewal now (foreground)',
        'B. Back'
    )

    while ($true) {
        $sel = Show-Menu -Title $title -Options $options
        switch ($sel) {
            0 {
                if (Get-Command -Name 'Invoke-SMTPConfig' -ErrorAction SilentlyContinue) {
                    Invoke-SMTPConfig
                } else {
                    Write-Host '  SMTP configurator not available' -ForegroundColor Yellow
                    Wait-AnyKey
                }
            }
            1 { Invoke-ScheduledTaskSetup }
            2 {
                $scriptPath = Join-Path $PSScriptRoot '..\..\Scripts\Invoke-RenewalBackground.ps1'
                $scriptPath = [System.IO.Path]::GetFullPath($scriptPath)
                if (Test-Path $scriptPath) {
                    & $scriptPath -Foreground
                } else {
                    Write-Host "  Renewal script not found at $scriptPath" -ForegroundColor Yellow
                    Wait-AnyKey
                }
            }
            3 { return }
            -1 { return }
            default { return }
        }
    }
}
