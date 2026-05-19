function Start-TUACME {
    <#
    .SYNOPSIS
        Starter TU-ACME Terminal UI til administration af Posh-ACME certifikater.
    #>
    [CmdletBinding()]
    param()

    # Tjek at Posh-ACME er installeret
    if (-not (Get-Module -ListAvailable -Name 'Posh-ACME')) {
        Write-Host ''
        Write-Host '  [FEJL] Posh-ACME modulet er ikke installeret.' -ForegroundColor Red
        Write-Host '  Installer med: Install-Module -Name Posh-ACME -Scope AllUsers' -ForegroundColor Yellow
        Write-Host ''
        return
    }

    # Saet admin-status i modul-scope
    $script:TUACMEIsAdmin = Get-AdminStatus

    # Opret konfigurationsmappe hvis den ikke eksisterer
    $configDir = Join-Path $env:ProgramData 'TU-ACME'
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    # Registrer Event Log kilde hvis admin
    if ($script:TUACMEIsAdmin) {
        Write-EventLogEntry -EventId 1000 -Message 'TU-ACME startet.' -EntryType Information
    }

    # Hovedmenu-loop
    $running = $true
    while ($running) {
        Invoke-ConsoleClear
        Show-StatusBar

        $menuOptions = @(
            '1. Kontostyring',
            '2. Bestil nyt certifikat',
            '3. Certifikat-dashboard',
            '4. Automatisering',
            '5. Eksport / Import',
            '6. IIS Integration',
            '7. Fejlsoegning / Logs',
            'Q. Afslut'
        )

        $selection = Show-Menu -Title 'TU-ACME v1.0 — Certifikatstyring' -Options $menuOptions

        switch ($selection) {
            -2 {
                # F3 — Staging-toggle (haandteres i Invoke-AccountMenu)
                Invoke-AccountMenu -StagingToggle
            }
            -1 {
                # ESC — Afslut
                $running = $false
            }
            0  { Invoke-AccountMenu }
            1  { Invoke-CertificateMenu -ShowOrder }
            2  { Invoke-CertificateDashboard }
            3  {
                if (-not $script:TUACMEIsAdmin) {
                    Show-StatusBar -AdminWarning 'Automatisering kraever administratorrettigheder'
                    Start-Sleep -Seconds 2
                } else {
                    Invoke-AutomationMenu
                }
            }
            4  { Invoke-ExportMenu }
            5  {
                if (-not $script:TUACMEIsAdmin) {
                    Show-StatusBar -AdminWarning 'IIS Integration kraever administratorrettigheder'
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
    Write-Host 'TU-ACME afsluttet.' -ForegroundColor Cyan
}
