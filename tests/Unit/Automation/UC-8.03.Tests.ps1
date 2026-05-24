#Requires -Modules Pester
Describe 'UC-8.03 - Scheduled task setup registers task via Register-ScheduledTask' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force
    }
    AfterAll {
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'invokes Register-ScheduledTask exactly once on a fresh install' {
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
            Mock New-ScheduledTaskAction    { [PSCustomObject]@{ Kind = 'Action' } }
            Mock New-ScheduledTaskTrigger   { [PSCustomObject]@{ Kind = 'Trigger' } }
            Mock New-ScheduledTaskPrincipal { [PSCustomObject]@{ Kind = 'Principal' } }
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

            Assert-MockCalled Register-ScheduledTask     -Times 1 -Scope It
            Assert-MockCalled New-ScheduledTaskAction    -Times 1 -Scope It
            Assert-MockCalled New-ScheduledTaskTrigger   -Times 1 -Scope It
            Assert-MockCalled New-ScheduledTaskPrincipal -Times 1 -Scope It
        }
    }
}
