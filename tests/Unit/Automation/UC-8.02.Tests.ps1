#Requires -Modules Pester
Describe 'UC-8.02 - Scheduled task setup prompts before overwriting existing task' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force
    }
    AfterAll {
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'does not call Register-ScheduledTask when the operator declines overwrite' {
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
            Mock Get-ScheduledTask          { [PSCustomObject]@{ TaskName = 'Posh-ACME-AutoRenewal' } }
            Mock New-ScheduledTaskAction    { [PSCustomObject]@{} }
            Mock New-ScheduledTaskTrigger   { [PSCustomObject]@{} }
            Mock New-ScheduledTaskPrincipal { [PSCustomObject]@{} }
            Mock Register-ScheduledTask     {}
            Mock Write-Host {}

            # Accept defaults for name/time/account, then decline overwrite.
            $script:_ans = @('', '', '', 'n')
            $script:_idx = 0
            Mock Read-Host {
                $i = $script:_idx; $script:_idx = $i + 1
                if ($i -ge $script:_ans.Count) { return '' }
                return $script:_ans[$i]
            }

            Invoke-ScheduledTaskSetup

            Assert-MockCalled Register-ScheduledTask -Times 0 -Scope It
        }
    }
}
