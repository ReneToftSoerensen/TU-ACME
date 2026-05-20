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

        $automationLabel = '4. Automation'
        $iisLabel        = '6. IIS Integration'
        $disabled        = @()

        if (-not $script:TUACMEIsAdmin) {
            $automationLabel = '4. Automation       (Requires admin)'
            $disabled       += 3
        }

        if (-not $script:OnWindows) {
            $iisLabel = '6. IIS Integration  (Windows only)'
            $disabled += 5
        } elseif (-not $script:TUACMEIsAdmin) {
            $iisLabel = '6. IIS Integration  (Requires admin)'
            $disabled += 5
        }

        $menuOptions = @(
            '1. Account Management',
            '2. Order new certificate',
            '3. Certificate Dashboard',
            $automationLabel,
            '5. Export / Import',
            $iisLabel,
            '7. Troubleshooting / Logs',
            'Q. Exit'
        )

        $selection = Show-Menu -Title 'TU-ACME v0.2.0 — Certificate Management' `
            -Options $menuOptions -DisabledIndices $disabled

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
            3  { Invoke-AutomationMenu }
            4  { Invoke-ExportMenu }
            5  { Invoke-IISMenu }
            6  { Invoke-LogViewer }
            7  { $running = $false }
        }
    }

    Invoke-ConsoleClear
    Write-Host 'TU-ACME exited.' -ForegroundColor Cyan
}
