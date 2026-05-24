#Requires -Modules Pester
Describe 'UC-8.04 - Scheduled task setup runs as SYSTEM with Highest run level' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force
    }
    AfterAll {
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'builds the principal with UserId=SYSTEM and RunLevel=Highest' {
        InModuleScope TU-ACME {
            function Get-ScheduledTask          { param($TaskName) }
            function New-ScheduledTaskAction    { param($Execute, $Argument) }
            function New-ScheduledTaskTrigger   { param([switch]$Daily, $At) }
            function New-ScheduledTaskPrincipal { param($UserId, $LogonType, $RunLevel) }
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
            Mock Set-TUACMEConfig    {}
            Mock Write-EventLogEntry {}
            Mock Get-ScheduledTask          { $null }
            Mock New-ScheduledTaskAction    { [PSCustomObject]@{} }
            Mock New-ScheduledTaskTrigger   { [PSCustomObject]@{} }
            Mock New-ScheduledTaskPrincipal { [PSCustomObject]@{} }
            Mock Register-ScheduledTask     {}
            Mock Write-Host {}

            $script:_ans = @('', '', '')
            $script:_idx = 0
            Mock Read-Host {
                $i = $script:_idx; $script:_idx = $i + 1
                if ($i -ge $script:_ans.Count) { return '' }
                return $script:_ans[$i]
            }

            Invoke-ScheduledTaskSetup

            Assert-MockCalled New-ScheduledTaskPrincipal -Times 1 -Scope It -ParameterFilter {
                $UserId -eq 'SYSTEM' -and $RunLevel -eq 'Highest'
            }
        }
    }
}
