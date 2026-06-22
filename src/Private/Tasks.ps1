<#
    Tasks.ps1 - Manage scheduled renewal tasks (T menu). Registers a Windows
    Scheduled Task that runs PoshAcme-Renew.ps1 (ISSUE-02) as SYSTEM. The
    generated parameter line uses the stable -ServerName / -AccountID seam.
#>

function Get-RenewalScriptPath {
    <# Expected path to PoshAcme-Renew.ps1 (repo root / deployed module dir). #>
    $dir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    return Join-Path $dir 'PoshAcme-Renew.ps1'
}

function Get-RenewalScheduledTaskCommand {
    <#
        .SYNOPSIS
            Builds the equivalent Task Scheduler command strings (for display and
            dry-run). Returns @{ ActionCmd; SchtasksCmd }.
    #>
    param(
        [string]$TaskName   = "$($script:TaskPrefix)RenewAll",
        [string]$ServerName = '',
        [string]$AccountID  = ''
    )
    $renewScript = Get-RenewalScriptPath
    $argLine = "-NoProfile -ExecutionPolicy Bypass -File `"$renewScript`""
    if ($ServerName) { $argLine += " -ServerName '$($ServerName -replace "'", "''")'" }
    if ($AccountID)  { $argLine += " -AccountID '$($AccountID -replace "'", "''")'" }

    $actionCmd = "pwsh.exe $argLine"
    $schtasks  = "schtasks /Create /TN `"$TaskName`" /TR `"$actionCmd`" /SC WEEKLY /D MON /ST 09:00 /RU SYSTEM /RL HIGHEST /F"
    return @{ ActionCmd = $actionCmd; SchtasksCmd = $schtasks }
}

function Get-TUACMERenewalTasks {
    <# Lists scheduled tasks whose name starts with the TU-ACME prefix. #>
    $result = @()
    try {
        $tasks = Get-ScheduledTask -TaskName "$($script:TaskPrefix)*" -ErrorAction Stop
    } catch {
        return $result
    }
    foreach ($t in $tasks) {
        $info    = $t | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue
        $action  = $t.Actions  | Select-Object -First 1
        $trigger = $t.Triggers | Select-Object -First 1
        $result += [pscustomobject]@{
            TaskName       = $t.TaskName
            State          = $t.State
            NextRunTime    = if ($info -and $info.NextRunTime) { $info.NextRunTime } else { $null }
            LastRunTime    = if ($info -and $info.LastRunTime) { $info.LastRunTime } else { $null }
            LastTaskResult = if ($info) { $info.LastTaskResult } else { 0 }
            Execute        = if ($action)  { $action.Execute }  else { '' }
            Arguments      = if ($action)  { $action.Arguments } else { '' }
            StartTime      = if ($trigger -and $trigger.StartBoundary) { $trigger.StartBoundary } else { '' }
        }
    }
    return $result
}

function Register-TUACMERenewalTask {
    <#
        .SYNOPSIS
            Registers (or replaces) a SYSTEM scheduled task that runs
            PoshAcme-Renew.ps1 with the -ServerName / -AccountID seam.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$TaskName,
        [Parameter(Mandatory)][datetime]$StartTime,
        [ValidateSet('Daily', 'Weekly')][string]$ScheduleType = 'Weekly',
        [string]$DayOfWeek = 'Monday',
        [string]$ServerName = '',
        [string]$AccountID  = ''
    )

    $renewScript = Get-RenewalScriptPath
    if (-not (Test-Path $renewScript)) {
        throw "PoshAcme-Renew.ps1 not found at: $renewScript`nCopy it next to the deployed module and try again."
    }

    $argLine = "-NoProfile -ExecutionPolicy Bypass -File `"$renewScript`""
    if ($ServerName) { $argLine += " -ServerName '$($ServerName -replace "'", "''")'" }
    if ($AccountID)  { $argLine += " -AccountID '$($AccountID -replace "'", "''")'" }
    $action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument $argLine

    switch ($ScheduleType) {
        'Daily'  { $trigger = New-ScheduledTaskTrigger -Daily -At $StartTime }
        'Weekly' { $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek ([DayOfWeek]$DayOfWeek) -At $StartTime }
    }

    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -WakeToRun -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
        -RestartCount 2 -RestartInterval (New-TimeSpan -Minutes 15)

    $fullName = if ($TaskName.StartsWith($script:TaskPrefix)) { $TaskName } else { $script:TaskPrefix + $TaskName }
    if (-not $PSCmdlet.ShouldProcess($fullName, 'Register scheduled task')) { return $fullName }
    Register-ScheduledTask -TaskName $fullName -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings -Force | Out-Null
    return $fullName
}

function Invoke-ManageScheduledTasks {
    Show-Banner
    Write-Step 'Manage scheduled renewal tasks'

    while ($true) {
        $tasks = Get-TUACMERenewalTasks
        Write-Host ''
        if (-not $tasks) {
            Write-Warn 'No TU-ACME scheduled renewal tasks found.'
            Write-Host "  (Tasks whose name starts with '$($script:TaskPrefix)' will appear here.)"
        } else {
            Write-Host 'Scheduled renewal tasks:' -ForegroundColor Cyan
            $i = 0
            foreach ($t in $tasks) {
                $i++
                $next = if ($t.NextRunTime) { (ConvertTo-DateTime $t.NextRunTime).ToString('yyyy-MM-dd HH:mm') } else { '-' }
                $last = if ($t.LastRunTime) { (ConvertTo-DateTime $t.LastRunTime).ToString('yyyy-MM-dd HH:mm') } else { '-' }
                $res  = switch ($t.LastTaskResult) {
                    0       { 'Success' }
                    267011  { 'Task not yet run' }
                    default { "Err $($t.LastTaskResult)" }
                }
                Write-Host ("  {0,2}: {1,-32} {2,-10} next:{3}  last:{4}  [{5}]" -f `
                    $i, $t.TaskName, $t.State, $next, $last, $res)
            }
        }

        Write-Host ''
        Write-Host 'Options:' -ForegroundColor Cyan
        Write-Host '  c          Create a new scheduled renewal task'
        Write-Host '  r <n>      Run task #n now'
        Write-Host '  l          Show the renewal log'
        Write-Host '  d <n>      Delete task #n'
        Write-Host '  x          Back to main menu'
        $line = Read-Host 'Choice'
        if (-not $line) { continue }
        $parts = $line.Trim() -split '\s+', 2
        $cmd   = $parts[0].ToLower()
        $arg   = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }

        switch ($cmd) {
            'x' { return }
            'c' { Invoke-CreateScheduledTask }
            'l' { Show-RenewalLog }
            'r' {
                if (-not $arg -or $arg -notmatch '^\d+$') { Write-Warn 'Provide a number.'; Wait-UI; continue }
                $idx = [int]$arg - 1
                if (-not $tasks -or $idx -lt 0 -or $idx -ge $tasks.Count) { Write-Warn 'Out of range.'; Wait-UI; continue }
                $t = $tasks[$idx]
                try { Start-ScheduledTask -TaskName $t.TaskName -ErrorAction Stop; Write-Ok "Task '$($t.TaskName)' started." }
                catch { Write-Err "Failed to start task: $_" }
                Wait-UI
            }
            'd' {
                if (-not $arg -or $arg -notmatch '^\d+$') { Write-Warn 'Provide a number.'; Wait-UI; continue }
                $idx = [int]$arg - 1
                if (-not $tasks -or $idx -lt 0 -or $idx -ge $tasks.Count) { Write-Warn 'Out of range.'; Wait-UI; continue }
                $t = $tasks[$idx]
                if (-not (Confirm-Prompt "Delete task '$($t.TaskName)'?")) { continue }
                try { Unregister-ScheduledTask -TaskName $t.TaskName -Confirm:$false -ErrorAction Stop; Write-Ok "Task deleted: $($t.TaskName)" }
                catch { Write-Err "Failed to delete task: $_" }
                Wait-UI
            }
            default { Write-Warn 'Unknown command.'; Wait-UI }
        }
    }
}

function Invoke-CreateScheduledTask {
    Write-Host ''
    Write-Step 'Create a new scheduled renewal task'

    $defaultName = "$($script:TaskPrefix)Renew-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $taskName = Read-Host "Task name (default: $defaultName)"
    if (-not $taskName) { $taskName = $defaultName }
    if (-not $taskName.StartsWith($script:TaskPrefix)) { $taskName = $script:TaskPrefix + $taskName }

    $accounts = Get-AllPAAccounts
    $srvName  = ''
    $acctID   = ''
    if ($accounts) {
        Write-Host ''
        Write-Host 'Available ACME accounts:' -ForegroundColor Cyan
        $i = 0
        foreach ($a in $accounts) {
            $i++
            $mail    = if ($a.Contact) { $a.Contact } else { '(no contact)' }
            $idShort = if ($a.AccountID.Length -gt 20) { $a.AccountID.Substring(0, 20) + '...' } else { $a.AccountID }
            Write-Host ("  {0,2}: [{1,-24}] {2,-22} ({3})" -f $i, $a.ServerName, $idShort, $mail)
        }
        Write-Host '   0: Use the currently active server/account (no -ServerName/-AccountID)'
        $sel = Read-Host 'Pick account (number)'
        if ($sel -match '^\d+$' -and [int]$sel -gt 0) {
            $idx = [int]$sel - 1
            if ($idx -ge 0 -and $idx -lt $accounts.Count) {
                $srvName = $accounts[$idx].ServerName
                $acctID  = $accounts[$idx].AccountID
                Write-Host "Using server='$srvName' account='$acctID'" -ForegroundColor Cyan
            } else { Write-Warn 'Out of range; using currently active context.' }
        } else { Write-Host 'Will use currently active server/account.' -ForegroundColor DarkGray }
    } else {
        Write-Warn 'No ACME accounts found. Task will use the currently active context.'
    }

    Write-Host ''
    Write-Host 'Schedule options:' -ForegroundColor Cyan
    Write-Host '  1: Weekly on Monday at 09:00  (recommended)'
    Write-Host '  2: Daily at 03:00'
    Write-Host '  3: Weekly on a different day/time'
    $schedChoice = Read-Host 'Choice (default: 1)'
    if (-not $schedChoice) { $schedChoice = '1' }

    $schedType = 'Weekly'; $startTime = Get-Date '09:00'; $dayOfWeek = 'Monday'
    switch ($schedChoice) {
        '1' { }
        '2' { $schedType = 'Daily'; $startTime = Get-Date '03:00' }
        '3' {
            $d = Read-Host 'Day of week (Monday/.../Sunday, default Monday)'
            if ($d -and ($d -as [DayOfWeek])) { $dayOfWeek = $d }
            $t = Read-Host 'Start time HH:mm (default 09:00)'
            if ($t) { try { $startTime = Get-Date $t } catch { Write-Warn "Invalid time '$t', using 09:00" } }
        }
        default { Write-Warn 'Invalid choice, using Weekly Monday 09:00' }
    }

    $renewScript = Get-RenewalScriptPath
    Write-Host ''
    Write-Step 'Confirm new scheduled task'
    Write-Host "Task name      : $taskName"
    Write-Host "Script         : $renewScript"
    Write-Host "Server         : $(if ($srvName) { $srvName } else { '(active context)' })"
    Write-Host "Account        : $(if ($acctID)  { $acctID  } else { '(active context)' })"
    $schedLabel = if ($schedType -eq 'Weekly') { "$schedType on $dayOfWeek at $($startTime.ToString('HH:mm'))" }
                  else { "$schedType at $($startTime.ToString('HH:mm'))" }
    Write-Host "Schedule       : $schedLabel"
    Write-Host 'Run as         : SYSTEM (highest privileges)'
    if (-not (Test-Path $renewScript)) {
        Write-Warn "WARNING: PoshAcme-Renew.ps1 not found at $renewScript"
        Write-Warn '         The task will fail until that file is deployed next to the module.'
    }
    if (-not (Confirm-Prompt 'Register this task?')) { return }

    if ($script:DryRun) {
        $cmds = Get-RenewalScheduledTaskCommand -TaskName $taskName -ServerName $srvName -AccountID $acctID
        Write-Warn 'DRY-RUN: no task registered.'
        Write-Host 'Equivalent pwsh.exe action:' -ForegroundColor DarkCyan
        Write-Host "  $($cmds.ActionCmd)" -ForegroundColor Gray
        Write-Host 'Equivalent schtasks.exe registration:' -ForegroundColor DarkCyan
        Write-Host "  $($cmds.SchtasksCmd)" -ForegroundColor Gray
        Wait-UI
        return
    }

    try {
        $registered = Register-TUACMERenewalTask -TaskName $taskName -StartTime $startTime `
            -ScheduleType $schedType -DayOfWeek $dayOfWeek -ServerName $srvName -AccountID $acctID
        Write-Ok "Task registered: $registered"
    } catch {
        Write-Err "Failed to register task: $_"
    }
    Wait-UI
}

function Show-RenewalLog {
    Write-Host ''
    Write-Step 'Renewal log'
    if (-not (Test-Path $script:LogPath)) {
        Write-Warn "Log file not found: $($script:LogPath)"
        Write-Host '(No renewal has run yet, or logging failed at runtime.)'
        Wait-UI
        return
    }
    Write-Host "Showing last 50 lines of: $($script:LogPath)" -ForegroundColor DarkGray
    Write-Host '---'
    try { Get-Content $script:LogPath -Tail 50 | ForEach-Object { Write-Host $_ } }
    catch { Write-Err "Could not read log: $_" }
    Write-Host '---'
    Wait-UI
}
