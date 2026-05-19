#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"
. "$PSScriptRoot\..\..\Fixtures\FakeObjects.ps1"

BeforeDiscovery { Import-TUACMEModule }

Describe 'Invoke-ScheduledTaskSetup' -Tag Unit, Automation {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        BeforeEach {
            $script:TUACMEIsAdmin = $true
            Mock -CommandName 'Write-Host'                  -MockWith {}
            Mock -CommandName 'Invoke-ConsoleClear'         -MockWith {}
            Mock -CommandName 'Invoke-ConsoleWaitKey'       -MockWith {}
            Mock -CommandName 'Get-TUACMEConfig'            -MockWith { New-FakeConfig }
            Mock -CommandName 'Set-TUACMEConfig'            -MockWith {}
            Mock -CommandName 'Show-Menu'                   -MockWith { 0 }   # SYSTEM account
            Mock -CommandName 'Get-ScheduledTask'           -MockWith { $null }  -ErrorAction SilentlyContinue
            Mock -CommandName 'New-ScheduledTaskAction'     -MockWith { [PSCustomObject]@{} }
            Mock -CommandName 'New-ScheduledTaskTrigger'    -MockWith { [PSCustomObject]@{} }
            Mock -CommandName 'New-ScheduledTaskSettingsSet' -MockWith { [PSCustomObject]@{} }
            Mock -CommandName 'New-ScheduledTaskPrincipal'  -MockWith { [PSCustomObject]@{} }
            Mock -CommandName 'Register-ScheduledTask'      -MockWith { New-FakeScheduledTask }
            Mock -CommandName 'Read-Host'                   -MockWith { '' }   # accept default time
        }

        Context 'Task does not exist — registers new task' {
            It 'calls Register-ScheduledTask once' {
                Invoke-ScheduledTaskSetup
                Should -Invoke Register-ScheduledTask -Times 1 -Exactly
            }
            It 'calls Set-TUACMEConfig to persist settings' {
                Invoke-ScheduledTaskSetup
                Should -Invoke Set-TUACMEConfig -Times 1 -Exactly
            }
        }

        Context 'Task already exists — user confirms overwrite' {
            BeforeEach {
                Mock -CommandName 'Get-ScheduledTask' -MockWith { New-FakeScheduledTask }
                Mock -CommandName 'Unregister-ScheduledTask' -MockWith {}
                $script:ri = 0
                $script:rseq = @('', 'J')   # default time, then confirm overwrite
                Mock -CommandName 'Read-Host' -MockWith { $r = $script:rseq[$script:ri]; $script:ri++; $r }
            }
            It 'unregisters old task before creating new' {
                Invoke-ScheduledTaskSetup
                Should -Invoke Unregister-ScheduledTask -Times 1 -Exactly
                Should -Invoke Register-ScheduledTask   -Times 1 -Exactly
            }
        }

        Context 'Task already exists — user declines overwrite' {
            BeforeEach {
                Mock -CommandName 'Get-ScheduledTask' -MockWith { New-FakeScheduledTask }
                Mock -CommandName 'Unregister-ScheduledTask' -MockWith {}
                $script:ri = 0
                $script:rseq = @('', 'N')
                Mock -CommandName 'Read-Host' -MockWith { $r = $script:rseq[$script:ri]; $script:ri++; $r }
            }
            It 'does not register new task' {
                Invoke-ScheduledTaskSetup
                Should -Invoke Register-ScheduledTask -Times 0
            }
        }

        Context 'Not admin — returns early' {
            BeforeEach {
                $script:TUACMEIsAdmin = $false
                Mock -CommandName 'Show-StatusBar' -MockWith {}
                Mock -CommandName 'Start-Sleep'    -MockWith {}
            }
            It 'does not call Register-ScheduledTask' {
                Invoke-ScheduledTaskSetup
                Should -Invoke Register-ScheduledTask -Times 0
            }
        }

        Context 'Register-ScheduledTask throws' {
            BeforeEach {
                Mock -CommandName 'Register-ScheduledTask' -MockWith { throw 'Access denied' }
            }
            It 'does not propagate exception' {
                { Invoke-ScheduledTaskSetup } | Should -Not -Throw
            }
        }
    }
}
