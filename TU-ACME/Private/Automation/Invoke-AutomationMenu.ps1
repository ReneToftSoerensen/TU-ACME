function Invoke-AutomationMenu {
    if (-not $script:TUACMEIsAdmin) {
        Show-StatusBar -AdminWarning 'Automatisering kræver administratorrettigheder'
        Start-Sleep -Seconds 2
        return
    }

    while ($true) {
        $options = @(
            '1. Opret Scheduled Task (automatisk fornyelse)',
            '2. Konfigurer SMTP-fejladvisering',
            '3. Send test-mail',
            'B. Tilbage'
        )
        $sel = Show-Menu -Title 'Automatisering' -Options $options

        switch ($sel) {
            -1 { return }
            0  { Invoke-ScheduledTaskSetup }
            1  { Invoke-SMTPConfig }
            2  {
                # Direkte test-mail uden at aabne hele SMTP-konfigurationen
                $subject = '[TU-ACME] Manuel test-mail'
                $body    = "Manuel test-mail fra TU-ACME.`n`nTidsstempel: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`nServer: $env:COMPUTERNAME"
                $ok = Send-TUACMEMail -Subject $subject -Body $body
                if ($ok) {
                    Write-Host '  Test-mail sendt.' -ForegroundColor Green
                } else {
                    Write-Host '  Fejl. Tjek SMTP-konfiguration.' -ForegroundColor Red
                }
                Start-Sleep -Seconds 2
            }
            3  { return }
        }
    }
}
