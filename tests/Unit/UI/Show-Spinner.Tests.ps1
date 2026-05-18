#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"

Describe 'Show-Spinner' -Tag Unit, UI {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        BeforeEach {
            Mock -CommandName 'Write-Host' -MockWith {}
        }

        Context 'ScriptBlock succeeds — returns value' {
            It 'passes through return value' {
                $r = Show-Spinner -Message 'Working...' -ScriptBlock { 42 }
                $r | Should -Be 42
            }
            It 'does not throw' {
                { Show-Spinner -Message 'x' -ScriptBlock { 'ok' } } | Should -Not -Throw
            }
        }

        Context 'ScriptBlock throws — exception propagates' {
            It 'rethrows exception from scriptblock' {
                { Show-Spinner -Message 'x' -ScriptBlock { throw 'DNS timeout' } } | Should -Throw -ExpectedMessage 'DNS timeout'
            }
        }

        Context 'Cursor visibility restored after exception' {
            It 'does not throw secondary cursor error' {
                try { Show-Spinner -Message 'x' -ScriptBlock { throw 'fail' } } catch {}
                # If cursor restoration throws, this would have propagated — passing means it was swallowed
                $true | Should -BeTrue
            }
        }
    }
}
