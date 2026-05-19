function Start-TUACME {
    <#
    .SYNOPSIS
        Starts the TU-ACME Terminal UI for managing Posh-ACME certificates.
    #>
    [CmdletBinding()]
    param()

    # Check that Posh-ACME is installed
    if (-not (Get-Module -ListAvailable -Name 'Posh-ACME')) {
        Write-Host ''
        Write-Host '  [ERROR] The Posh-ACME module is not installed.' -ForegroundColor Red
        Write-Host '  Install with: Install-Module -Name Posh-ACME -Scope AllUsers' -ForegroundColor Yellow
        Write-Host ''
        return
    }

    # Set admin status in module scope
    $script:TUACMEIsAdmin = Get-AdminStatus

    # Create configuration folder if it does not exist
    $configDir = Join-Path $env:ProgramData 'TU-ACME'
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    # Register Event Log source if admin
    if ($script:TUACMEIsAdmin) {
        Write-EventLogEntry -EventId 1000 -Message 'TU-ACME started.' -EntryType Information
    }

    # Main menu loop
    $running = $true
    while ($running) {
        Invoke-ConsoleClear
        Show-StatusBar

        $menuOptions = @(
            '1. Account Management',
            '2. Order new certificate',
            '3. Certificate Dashboard',
            '4. Automation',
            '5. Export / Import',
            '6. IIS Integration',
            '7. Troubleshooting / Logs',
            'Q. Exit'
        )

        $selection = Show-Menu -Title 'TU-ACME v0.0.2 — Certificate Management' -Options $menuOptions

        switch ($selection) {
            -2 {
                # F3 — Staging toggle (handled in Invoke-AccountMenu)
                Invoke-AccountMenu -StagingToggle
            }
            -1 {
                # ESC — Exit
                $running = $false
            }
            0  { Invoke-AccountMenu }
            1  { Invoke-CertificateMenu -ShowOrder }
            2  { Invoke-CertificateDashboard }
            3  {
                if (-not $script:TUACMEIsAdmin) {
                    Show-StatusBar -AdminWarning 'Automation requires administrator privileges'
                    Start-Sleep -Seconds 2
                } else {
                    Invoke-AutomationMenu
                }
            }
            4  { Invoke-ExportMenu }
            5  {
                if (-not $script:OnWindows) {
                    Write-Host ''
                    Write-Host '  IIS Integration is only available on Windows.' -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                } elseif (-not $script:TUACMEIsAdmin) {
                    Show-StatusBar -AdminWarning 'IIS Integration requires administrator privileges'
                    Start-Sleep -Seconds 2
                } else {
                    Invoke-IISMenu
                }
            }
            6  { Invoke-LogViewer }
            7  { $running = $false }
        }
    }

    Invoke-ConsoleClear
    Write-Host 'TU-ACME exited.' -ForegroundColor Cyan
}
