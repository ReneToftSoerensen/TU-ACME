BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Install-TUACMEScheduledTask (UC-7.01 / AC-E.1)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $true }
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsAdministrator { $true }
        Mock -ModuleName 'TU-ACME' Write-TUACMEEventLog { }
        Mock -ModuleName 'TU-ACME' Write-Host { }
        Mock -ModuleName 'TU-ACME' New-ScheduledTaskAction { [pscustomobject]@{ Execute = $Execute; Argument = $Argument } }
        Mock -ModuleName 'TU-ACME' New-ScheduledTaskTrigger { [pscustomobject]@{ AtStartup = $AtStartup; Once = $Once } }
        Mock -ModuleName 'TU-ACME' New-ScheduledTaskPrincipal { [pscustomobject]@{ UserId = $UserId } }
        Mock -ModuleName 'TU-ACME' Register-ScheduledTask { [pscustomobject]@{ TaskName = $TaskName } }
    }

    It 'throws on non-Windows platforms' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $false }

        {
            InModuleScope 'TU-ACME' { Install-TUACMEScheduledTask }
        } | Should -Throw '*requires Windows*'
    }

    It 'throws without an elevated session' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsAdministrator { $false }

        {
            InModuleScope 'TU-ACME' { Install-TUACMEScheduledTask }
        } | Should -Throw '*Administrator*'
    }

    It 'registers the TU-ACME-Renewal task' {
        $null = InModuleScope 'TU-ACME' { Install-TUACMEScheduledTask }

        Should -Invoke -ModuleName 'TU-ACME' Register-ScheduledTask -Times 1 -Exactly -ParameterFilter {
            $TaskName -eq 'TU-ACME-Renewal' -and $Force -eq $true
        }
    }

    It 'targets powershell.exe with the renewal script path' {
        $null = InModuleScope 'TU-ACME' { Install-TUACMEScheduledTask }

        Should -Invoke -ModuleName 'TU-ACME' New-ScheduledTaskAction -Times 1 -Exactly -ParameterFilter {
            $Execute -eq 'powershell.exe' -and
            $Argument -like '*Invoke-Renewal.ps1*' -and
            $Argument -like '*-NonInteractive*'
        }
    }

    It 'runs as SYSTEM' {
        $null = InModuleScope 'TU-ACME' { Install-TUACMEScheduledTask }

        Should -Invoke -ModuleName 'TU-ACME' New-ScheduledTaskPrincipal -Times 1 -Exactly -ParameterFilter {
            $UserId -like '*SYSTEM*'
        }
    }

    It 'schedules an hourly repetition and a startup trigger' {
        $null = InModuleScope 'TU-ACME' { Install-TUACMEScheduledTask }

        Should -Invoke -ModuleName 'TU-ACME' New-ScheduledTaskTrigger -Times 1 -Exactly -ParameterFilter {
            $AtStartup -eq $true
        }
        Should -Invoke -ModuleName 'TU-ACME' New-ScheduledTaskTrigger -Times 1 -Exactly -ParameterFilter {
            $Once -eq $true -and $RepetitionInterval.TotalHours -eq 1
        }
    }

    It 'logs event 1008 on successful installation' {
        $null = InModuleScope 'TU-ACME' { Install-TUACMEScheduledTask }

        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 1008 -and $EntryType -eq 'Information'
        }
    }

    It 'returns the task name and schedule' {
        $result = InModuleScope 'TU-ACME' { Install-TUACMEScheduledTask }

        $result.TaskName | Should -Be 'TU-ACME-Renewal'
        $result.IntervalHours | Should -Be 1
        $result.ScriptPath | Should -BeLike '*Invoke-Renewal.ps1'
    }

    It 'does not register anything when elevation is missing' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsAdministrator { $false }

        {
            InModuleScope 'TU-ACME' { Install-TUACMEScheduledTask }
        } | Should -Throw

        Should -Invoke -ModuleName 'TU-ACME' Register-ScheduledTask -Times 0 -Exactly
    }
}
