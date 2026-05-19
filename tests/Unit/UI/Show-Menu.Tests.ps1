#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"

BeforeDiscovery { Import-TUACMEModule }

Describe 'Show-Menu' -Tag Unit, UI {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        BeforeEach {
            Mock -CommandName 'Write-Host'           -MockWith {}
            Mock -CommandName 'Invoke-ConsoleClear'  -MockWith {}
        }

        function Set-KeySequence {
            param([System.ConsoleKeyInfo[]] $Keys)
            $script:_ki = 0
            Mock -CommandName 'Invoke-ConsoleReadKey' -MockWith {
                $k = $script:_Keys[$script:_ki]; $script:_ki++; return $k
            }
            $script:_Keys = $Keys
        }

        Context 'Enter on first item returns index 0' {
            BeforeEach {
                Set-KeySequence @(
                    (New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Enter, $false, $false, $false))
                )
            }
            It 'returns 0' {
                $r = Show-Menu -Title 'Test' -Options @('A', 'B', 'C')
                $r | Should -Be 0
            }
        }

        Context 'Down then Enter returns index 1' {
            BeforeEach {
                Set-KeySequence @(
                    (New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::DownArrow, $false, $false, $false)),
                    (New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Enter, $false, $false, $false))
                )
            }
            It 'returns 1' {
                $r = Show-Menu -Title 'Test' -Options @('A', 'B', 'C')
                $r | Should -Be 1
            }
        }

        Context 'Up on first item wraps to last' {
            BeforeEach {
                Set-KeySequence @(
                    (New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::UpArrow, $false, $false, $false)),
                    (New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Enter, $false, $false, $false))
                )
            }
            It 'returns last index' {
                $r = Show-Menu -Title 'Test' -Options @('A', 'B', 'C')
                $r | Should -Be 2
            }
        }

        Context 'ESC returns -1' {
            BeforeEach {
                Set-KeySequence @(
                    (New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Escape, $false, $false, $false))
                )
            }
            It 'returns -1' {
                $r = Show-Menu -Title 'Test' -Options @('A', 'B')
                $r | Should -Be -1
            }
        }

        Context 'F3 returns -2' {
            BeforeEach {
                Set-KeySequence @(
                    (New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::F3, $false, $false, $false))
                )
            }
            It 'returns -2' {
                $r = Show-Menu -Title 'Test' -Options @('A', 'B')
                $r | Should -Be -2
            }
        }

        Context 'Digit shortcut selects correct item' {
            BeforeEach {
                Set-KeySequence @(
                    (New-Object System.ConsoleKeyInfo('2', [System.ConsoleKey]::D2, $false, $false, $false))
                )
            }
            It 'returns 1 for key 2' {
                $r = Show-Menu -Title 'Test' -Options @('A', 'B', 'C')
                $r | Should -Be 1
            }
        }

        Context 'InitialIndex respected' {
            BeforeEach {
                Set-KeySequence @(
                    (New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Enter, $false, $false, $false))
                )
            }
            It 'returns InitialIndex value on immediate Enter' {
                $r = Show-Menu -Title 'Test' -Options @('A', 'B', 'C') -InitialIndex 2
                $r | Should -Be 2
            }
        }
    }
}
