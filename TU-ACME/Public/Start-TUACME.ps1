function Start-TUACME {
    <#
    .SYNOPSIS
        Starts the TU-ACME Terminal UI for managing Posh-ACME certificates
        against an internal corporate ACME CA.
    #>
    [CmdletBinding()]
    param()

    if (-not (Get-Module -ListAvailable -Name 'Posh-ACME')) {
        Write-Host ''
        Write-Host '  [ERROR] The Posh-ACME module is not installed.' -ForegroundColor Red
        Write-Host '  Install with: Install-Module -Name Posh-ACME -Scope AllUsers' -ForegroundColor Yellow
        Write-Host ''
        return
    }

    $script:TUACMEIsAdmin = Get-AdminStatus

    $configDir = Join-Path $env:ProgramData 'TU-ACME'
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    if ($script:TUACMEIsAdmin) {
        Write-EventLogEntry -EventId 1000 -Message 'TU-ACME started.' -EntryType Information
    }

    # First-run gate.
    $cfg = Get-TUACMEConfig
    if (-not $cfg.Acme.Initialized) {
        Initialize-TUACMEEnvironment
        $cfg = Get-TUACMEConfig
        if (-not $cfg.Acme.Initialized) { return }
    }

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
            '1. Order new certificate',
            '2. Dry-run order (staging)',
            '3. Certificate Dashboard',
            $automationLabel,
            '5. Export / Import',
            $iisLabel,
            '7. DNS plugin configuration',
            '8. Troubleshooting / Logs',
            'Q. Exit'
        )

        $selection = Show-Menu -Title 'TU-ACME v0.3.2 - Certificate Management' `
            -Options $menuOptions -DisabledIndices $disabled

        switch ($selection) {
            -1 { $running = $false }
            0  { Invoke-OrderCertificate }
            1  { Invoke-DryRunOrder }
            2  { Invoke-CertificateDashboard }
            3  { Invoke-AutomationMenu }
            4  { Invoke-ExportMenu }
            5  { Invoke-IISMenu }
            6  { Invoke-DnsPluginConfig }
            7  { Invoke-LogViewer }
            8  { $running = $false }
        }
    }

    Invoke-ConsoleClear
    Write-Host 'TU-ACME exited.' -ForegroundColor Cyan
}
