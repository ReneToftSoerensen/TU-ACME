function Install-TUACMEScheduledTask {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$TaskName = 'TU-ACME-Renewal',

        [ValidateRange(1, [int]::MaxValue)]
        [int]$IntervalHours = 1
    )

    if (-not (Test-TUACMEIsWindows)) {
        throw 'Scheduled task installation requires Windows.'
    }
    if (-not (Test-TUACMEIsAdministrator)) {
        throw 'Scheduled task installation requires an elevated session. Run PowerShell as Administrator.'
    }

    $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $scriptPath = Join-Path (Join-Path $moduleRoot 'Scripts') 'Invoke-Renewal.ps1'

    # powershell.exe rather than pwsh: present on every supported Windows
    # host and safe for the SYSTEM context (dual-target floor, UC-11.02).
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}"' -f $scriptPath)
    $startupTrigger = New-ScheduledTaskTrigger -AtStartup
    $hourlyTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Hours $IntervalHours)
    $principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType 'ServiceAccount' -RunLevel 'Highest'

    $null = Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($startupTrigger, $hourlyTrigger) -Principal $principal -Force -ErrorAction Stop

    Write-TUACMEEventLog -EventId 1008 -EntryType Information -Message ('Scheduled renewal task ''{0}'' installed (every {1} hour(s) and at startup, as SYSTEM).' -f $TaskName, $IntervalHours)
    Write-Host ('Scheduled task ''{0}'' installed: every {1} hour(s) and at startup, running as SYSTEM.' -f $TaskName, $IntervalHours) -ForegroundColor Cyan

    return [pscustomobject]@{
        TaskName      = $TaskName
        ScriptPath    = $scriptPath
        IntervalHours = $IntervalHours
    }
}
