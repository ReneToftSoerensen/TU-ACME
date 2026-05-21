#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"

BeforeDiscovery { Import-TUACMEModule }

Describe 'Show-StatusBar' -Tag Unit, UI {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        BeforeEach {
            Mock -CommandName 'Write-Host'               -MockWith {}
            # Mock the console helpers so the real Windows cursor
            # doesn't move during tests (otherwise Pester output
            # overwrites the buffer from the top — looks like the
            # screen got cleared).
            Mock -CommandName 'Set-ConsoleCursorPos'     -MockWith {}
            Mock -CommandName 'Set-ConsoleCursorVisible' -MockWith {}
            Mock -CommandName 'Get-ConsoleWidth'         -MockWith { 80 }
            Mock -CommandName 'Get-ConsoleHeight'        -MockWith { 24 }
            Mock -CommandName 'Get-ConsoleCursorLeft'    -MockWith { 0 }
            Mock -CommandName 'Get-ConsoleCursorTop'     -MockWith { 0 }
        }

        It 'does not throw with no parameters' {
            { Show-StatusBar } | Should -Not -Throw
        }
        It 'does not throw with ActiveAccount' {
            { Show-StatusBar -ActiveAccount 'admin@test.dk | Production' } | Should -Not -Throw
        }
        It 'does not throw with AdminWarning' {
            { Show-StatusBar -AdminWarning 'Requires admin privileges' } | Should -Not -Throw
        }
        It 'calls Write-Host at least once' {
            Show-StatusBar -ActiveAccount 'test'
            Should -Invoke Write-Host -Times 1 -Exactly
        }
        It 'uses red background for AdminWarning' {
            $script:bgUsed = $null
            Mock -CommandName 'Write-Host' -MockWith { $script:bgUsed = $BackgroundColor }
            Show-StatusBar -AdminWarning 'Warning'
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
