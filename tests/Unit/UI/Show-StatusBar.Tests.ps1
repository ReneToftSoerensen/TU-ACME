#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"

BeforeDiscovery { Import-TUACMEModule }

Describe 'Show-StatusBar' -Tag Unit, UI {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        BeforeEach {
            Mock -CommandName 'Write-Host' -MockWith {}
        }

        It 'does not throw with no parameters' {
            { Show-StatusBar } | Should -Not -Throw
        }
        It 'does not throw with ActiveAccount' {
            { Show-StatusBar -ActiveAccount 'admin@test.dk | Production' } | Should -Not -Throw
        }
        It 'does not throw with AdminWarning' {
            { Show-StatusBar -AdminWarning 'Kræver admin-rettigheder' } | Should -Not -Throw
        }
        It 'calls Write-Host at least once' {
            Show-StatusBar -ActiveAccount 'test'
            Should -Invoke Write-Host -Times 1 -Exactly
        }
        It 'uses red background for AdminWarning' {
            $script:bgUsed = $null
            Mock -CommandName 'Write-Host' -MockWith { $script:bgUsed = $BackgroundColor }
            Show-StatusBar -AdminWarning 'Advarsel'
            $script:bgUsed | Should -Be 'Red'
        }
        It 'uses gray background for normal bar' {
            $script:bgUsed = $null
            Mock -CommandName 'Write-Host' -MockWith { $script:bgUsed = $BackgroundColor }
            Show-StatusBar
            $script:bgUsed | Should -Be 'Gray'
        }
    }
}
