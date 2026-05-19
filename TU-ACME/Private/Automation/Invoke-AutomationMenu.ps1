function Invoke-AutomationMenu {
    if (-not $script:TUACMEIsAdmin) {
        Show-StatusBar -AdminWarning 'Automation requires administrator privileges'
        Start-Sleep -Seconds 2
        return
    }

    while ($true) {
        $options = @(
            '1. Create Scheduled Task (automatic renewal)',
            '2. Configure SMTP failure notification',
            '3. Send test email',
            'B. Back'
        )
        $sel = Show-Menu -Title 'Automation' -Options $options

        switch ($sel) {
            -1 { return }
            0  { Invoke-ScheduledTaskSetup }
            1  { Invoke-SMTPConfig }
            2  {
                # Direct test email without opening the full SMTP configuration
                $subject = '[TU-ACME] Manual test email'
                $body    = "Manual test email from TU-ACME.`n`nTimestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`nServer: $env:COMPUTERNAME"
                $ok = Send-TUACMEMail -Subject $subject -Body $body
                if ($ok) {
                    Write-Host '  Test email sent.' -ForegroundColor Green
                } else {
                    Write-Host '  Error. Check SMTP configuration.' -ForegroundColor Red
                }
                Start-Sleep -Seconds 2
            }
            3  { return }
        }
    }
}
