#Requires -Modules Pester
Describe 'UC-8.01 - Scheduled task setup prompts for and persists name/time/account' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc801-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
    }
    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'persists the chosen TaskName, RunTime, and RunAsAccount via Set-TUACMEConfig' {
        InModuleScope TU-ACME {
            # Stub Windows-only ScheduledTask cmdlets so Mock has something to bind to.
            function Get-ScheduledTask          { param($TaskName) }
            function New-ScheduledTaskAction    { param($Execute, $Argument) [PSCustomObject]@{ Execute = $Execute; Argument = $Argument } }
            function New-ScheduledTaskTrigger   { param([switch]$Daily, $At) [PSCustomObject]@{ Daily = $Daily; At = $At } }
            function New-ScheduledTaskPrincipal { param($UserId, $LogonType, $RunLevel) [PSCustomObject]@{ UserId = $UserId; LogonType = $LogonType; RunLevel = $RunLevel } }
            function Register-ScheduledTask     { param($TaskName, $Action, $Trigger, $Principal, [switch]$Force) }

            Mock Get-TUACMEConfig {
                [PSCustomObject]@{
                    ScheduledTask = [PSCustomObject]@{
                        TaskName     = 'Posh-ACME-AutoRenewal'
                        RunTime      = '03:00'
                        RunAsAccount = 'SYSTEM'
                    }
                }
            }
            $script:_persisted = $null
            Mock Set-TUACMEConfig    { param($Config) $script:_persisted = $Config }
            Mock Write-EventLogEntry {}
            Mock Get-ScheduledTask          { $null }
            Mock New-ScheduledTaskAction    { [PSCustomObject]@{} }
            Mock New-ScheduledTaskTrigger   { [PSCustomObject]@{} }
            Mock New-ScheduledTaskPrincipal { [PSCustomObject]@{} }
            Mock Register-ScheduledTask     {}
            Mock Write-Host {}

            # Accept all three defaults.
            $script:_ans = @('', '', '')
            $script:_idx = 0
            Mock Read-Host {
                $i = $script:_idx; $script:_idx = $i + 1
                if ($i -ge $script:_ans.Count) { return '' }
                return $script:_ans[$i]
            }

            Invoke-ScheduledTaskSetup

            Assert-MockCalled Set-TUACMEConfig -Times 1 -Scope It
            $script:_persisted.ScheduledTask.TaskName     | Should -Be 'Posh-ACME-AutoRenewal'
            $script:_persisted.ScheduledTask.RunTime      | Should -Be '03:00'
            $script:_persisted.ScheduledTask.RunAsAccount | Should -Be 'SYSTEM'
        }
    }
}
