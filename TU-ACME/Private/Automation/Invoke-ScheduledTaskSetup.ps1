function Invoke-ScheduledTaskSetup {
    if (-not $script:TUACMEIsAdmin) {
        Show-StatusBar -AdminWarning 'Scheduled Tasks requires administrator privileges'
        Start-Sleep -Seconds 2
        return
    }

    if (-not $script:OnWindows) {
        Invoke-ConsoleClear
        Write-Host '  Scheduled Tasks is not available on Linux/macOS.' -ForegroundColor Yellow
        Write-Host '  Use cron to schedule automatic renewal.' -ForegroundColor Gray
        Write-Host ''
        Write-Host '  Example crontab line (daily at 03:00):' -ForegroundColor DarkGray
        Write-Host '  0 3 * * * pwsh -NonInteractive -File "/pfx/Invoke-RenewalBackground.ps1"' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '  Press any key...' -ForegroundColor DarkGray
        Invoke-ConsoleWaitKey
        return
    }

    Invoke-ConsoleClear
    Write-Host '  === Create Scheduled Task for automatic renewal ===' -ForegroundColor Cyan
    Write-Host ''

    $config    = Get-TUACMEConfig
    $taskCfg   = $config.ScheduledTask
    $scriptPath = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules\TU-ACME\Scripts\Invoke-RenewalBackground.ps1"

    $runTime = Read-Host "  Run time (HH:MM, default: $($taskCfg.RunTime))"
    if ($runTime -eq '') { $runTime = $taskCfg.RunTime }

    $accountOptions = @('1. SYSTEM account', '2. Specific user account')
    $accSel = Show-Menu -Title 'Run as' -Options $accountOptions
    if ($accSel -lt 0) { return }

    $runAs = 'SYSTEM'
    if ($accSel -eq 1) {
        $runAs = Read-Host '  Username (e.g. DOMAIN\ServiceAccount)'
        if ($runAs -eq '') { return }
    }

    # Check if task already exists
    $existing = Get-ScheduledTask -TaskName $taskCfg.TaskName -ErrorAction SilentlyContinue
    if ($existing -ne $null) {
        $overwrite = Read-Host "  Task '$($taskCfg.TaskName)' already exists. Overwrite? (Y/N)"
        if ($overwrite -notmatch '^[Yy]') { return }
        Unregister-ScheduledTask -TaskName $taskCfg.TaskName -Confirm:$false
    }

    try {
        $action  = New-ScheduledTaskAction `
            -Execute 'powershell.exe' `
            -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""

        $trigger = New-ScheduledTaskTrigger -Daily -At $runTime

        $settings = New-ScheduledTaskSettingsSet `
            -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
            -StartWhenAvailable

        if ($runAs -eq 'SYSTEM') {
            $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest
            Register-ScheduledTask `
                -TaskName $taskCfg.TaskName `
                -Action   $action `
                -Trigger  $trigger `
                -Settings $settings `
                -Principal $principal | Out-Null
        } else {
            Register-ScheduledTask `
                -TaskName $taskCfg.TaskName `
                -Action   $action `
                -Trigger  $trigger `
                -Settings $settings `
                -User     $runAs `
                -RunLevel Highest | Out-Null
        }

        # Save configuration
        $taskCfg.RunTime      = $runTime
        $taskCfg.RunAsAccount = $runAs
        $config.ScheduledTask = $taskCfg
        Set-TUACMEConfig -Config $config

        Write-Host "  Scheduled Task '$($taskCfg.TaskName)' created." -ForegroundColor Green
        Write-Host "  Schedule: daily at $runTime as $runAs" -ForegroundColor White
    } catch {
        Write-Host "  Error creating task: $_" -ForegroundColor Red
    }

    Write-Host ''
    Write-Host '  Press any key...' -ForegroundColor DarkGray
    Invoke-ConsoleWaitKey
}
