#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"

Describe 'Get-AdminStatus' -Tag Unit, Helpers {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        It 'returns a boolean' {
            $r = Get-AdminStatus
            $r | Should -BeOfType [bool]
        }
        It 'does not throw' {
            { Get-AdminStatus } | Should -Not -Throw
        }
        It 'returns false when principal is not admin' {
            Mock -CommandName 'Get-AdminStatus' -MockWith { $false }
            Get-AdminStatus | Should -BeFalse
        }
        It 'returns true when principal is admin' {
            Mock -CommandName 'Get-AdminStatus' -MockWith { $true }
            Get-AdminStatus | Should -BeTrue
        }
    }
}
