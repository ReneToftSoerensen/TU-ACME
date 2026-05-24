function Invoke-ScheduledTaskSetup {
    <#
    .SYNOPSIS
        Install the Posh-ACME-AutoRenewal scheduled task.
    .DESCRIPTION
        Prompts for task name, run time, and run-as account using the
        current TU-ACME config as defaults, then registers a daily task
        that runs Scripts\Invoke-RenewalBackground.ps1 as SYSTEM with
        the Highest run level. Persists any edits to config.json and
        emits Event 1008 on success.
    #>
    [CmdletBinding()]
    param()

    Write-Host ''
    Write-Host '  === Scheduled task setup ===' -ForegroundColor Cyan
    Write-Host ''

    $cfg = Get-TUACMEConfig

    # Surface defaults from config (fall back to module defaults).
    $defaultName    = 'Posh-ACME-AutoRenewal'
    $defaultTime    = '03:00'
    $defaultRunAs   = 'SYSTEM'
    if ($cfg -and $cfg.PSObject.Properties.Match('ScheduledTask').Count -gt 0 -and $cfg.ScheduledTask) {
        if ($cfg.ScheduledTask.PSObject.Properties.Match('TaskName').Count -gt 0 -and
            -not [string]::IsNullOrWhiteSpace($cfg.ScheduledTask.TaskName)) {
            $defaultName = [string]$cfg.ScheduledTask.TaskName
        }
        if ($cfg.ScheduledTask.PSObject.Properties.Match('RunTime').Count -gt 0 -and
            -not [string]::IsNullOrWhiteSpace($cfg.ScheduledTask.RunTime)) {
            $defaultTime = [string]$cfg.ScheduledTask.RunTime
        }
        if ($cfg.ScheduledTask.PSObject.Properties.Match('RunAsAccount').Count -gt 0 -and
            -not [string]::IsNullOrWhiteSpace($cfg.ScheduledTask.RunAsAccount)) {
            $defaultRunAs = [string]$cfg.ScheduledTask.RunAsAccount
        }
    }

    # ---- 1. Task name ----------------------------------------------------
    $nameInput = Read-Host "Task name [$defaultName]"
    if ([string]::IsNullOrWhiteSpace($nameInput)) { $taskName = $defaultName }
    else                                          { $taskName = $nameInput.Trim() }

    # ---- 2. Run time (HH:mm) --------------------------------------------
    $runTime = ''
    while ($true) {
        $timeInput = Read-Host "Run time HH:mm [$defaultTime]"
        if ([string]::IsNullOrWhiteSpace($timeInput)) { $runTime = $defaultTime }
        else                                          { $runTime = $timeInput.Trim() }
        if ($runTime -match '^\d{2}:\d{2}$') { break }
        Write-Host "  Invalid time '$runTime'. Use HH:mm (24h)." -ForegroundColor Yellow
    }

    # ---- 3. Run-as account ----------------------------------------------
    $runAsInput = Read-Host "Run as account [$defaultRunAs]"
    if ([string]::IsNullOrWhiteSpace($runAsInput)) { $runAs = $defaultRunAs }
    else                                           { $runAs = $runAsInput.Trim() }

    # ---- 4. Overwrite check ---------------------------------------------
    $existing = $null
    try {
        $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    } catch {
        $existing = $null
    }
    if ($existing) {
        $overwrite = Read-Host "Task '$taskName' already exists. Overwrite? (y/N)"
        if ($overwrite -notmatch '^y$') {
            Write-Host '  Cancelled.' -ForegroundColor Yellow
            return
        }
    }

    # ---- 5. Build action / trigger / principal --------------------------
    $scriptPath = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules\TU-ACME\Scripts\Invoke-RenewalBackground.ps1'
    $action     = New-ScheduledTaskAction `
                    -Execute  'powershell.exe' `
                    -Argument "-NonInteractive -WindowStyle Hidden -File `"$scriptPath`""
    $trigger    = New-ScheduledTaskTrigger -Daily -At $runTime
    $principal  = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

    try {
        Register-ScheduledTask `
            -TaskName  $taskName `
            -Action    $action `
            -Trigger   $trigger `
            -Principal $principal `
            -Force | Out-Null
    } catch {
        Write-Host "  Failed to register task: $($_.Exception.Message)" -ForegroundColor Yellow
        return
    }

    Write-Host "  Scheduled task '$taskName' installed." -ForegroundColor Green

    Write-EventLogEntry -EventId 1008 -EntryType Information `
        -Message "Scheduled task '$taskName' installed (runs daily at $runTime as $runAs)"

    # ---- 6. Persist edits back to config --------------------------------
    if ($null -eq $cfg) {
        $cfg = [PSCustomObject]@{ ScheduledTask = [PSCustomObject]@{} }
    }
    if ($cfg.PSObject.Properties.Match('ScheduledTask').Count -eq 0 -or $null -eq $cfg.ScheduledTask) {
        $cfg | Add-Member -NotePropertyName ScheduledTask -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    $cfg.ScheduledTask | Add-Member -NotePropertyName TaskName     -NotePropertyValue $taskName -Force
    $cfg.ScheduledTask | Add-Member -NotePropertyName RunTime      -NotePropertyValue $runTime  -Force
    $cfg.ScheduledTask | Add-Member -NotePropertyName RunAsAccount -NotePropertyValue $runAs    -Force

    Set-TUACMEConfig -Config $cfg
}
