function Invoke-ScheduledTaskSetup {
    if (-not $script:TUACMEIsAdmin) {
        Show-StatusBar -AdminWarning 'Scheduled Tasks kræver administratorrettigheder'
        Start-Sleep -Seconds 2
        return
    }

    [Console]::Clear()
    Write-Host '  === Opret Scheduled Task til automatisk fornyelse ===' -ForegroundColor Cyan
    Write-Host ''

    $config    = Get-TUACMEConfig
    $taskCfg   = $config.ScheduledTask
    $scriptPath = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules\TU-ACME\Scripts\Invoke-RenewalBackground.ps1"

    $runTime = Read-Host "  Kørselstidspunkt (HH:MM, standard: $($taskCfg.RunTime))"
    if ($runTime -eq '') { $runTime = $taskCfg.RunTime }

    $accountOptions = @('1. SYSTEM-konto', '2. Specifik brugerkonto')
    $accSel = Show-Menu -Title 'Kør som' -Options $accountOptions
    if ($accSel -lt 0) { return }

    $runAs = 'SYSTEM'
    if ($accSel -eq 1) {
        $runAs = Read-Host '  Brugernavn (f.eks. DOMAIN\ServiceAccount)'
        if ($runAs -eq '') { return }
    }

    # Tjek om task allerede eksisterer
    $existing = Get-ScheduledTask -TaskName $taskCfg.TaskName -ErrorAction SilentlyContinue
    if ($existing -ne $null) {
        $overwrite = Read-Host "  Task '$($taskCfg.TaskName)' eksisterer allerede. Overskriv? (J/N)"
        if ($overwrite -notmatch '^[Jj]') { return }
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

        # Gem konfiguration
        $taskCfg.RunTime      = $runTime
        $taskCfg.RunAsAccount = $runAs
        $config.ScheduledTask = $taskCfg
        Set-TUACMEConfig -Config $config

        Write-Host "  Scheduled Task '$($taskCfg.TaskName)' oprettet." -ForegroundColor Green
        Write-Host "  Kørsel: dagligt kl. $runTime som $runAs" -ForegroundColor White
    } catch {
        Write-Host "  Fejl ved oprettelse af task: $_" -ForegroundColor Red
    }

    Write-Host ''
    Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
    [Console]::ReadKey($true) | Out-Null
}
