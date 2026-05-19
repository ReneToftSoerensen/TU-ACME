#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"

BeforeDiscovery { Import-TUACMEModule }

Describe 'ConvertTo-MaskedInput' -Tag Unit, Helpers {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        BeforeEach {
            Mock -CommandName 'Write-Host' -MockWith {}
        }

        Context 'Enter on empty input returns empty string' {
            BeforeEach {
                Mock -CommandName 'Invoke-ConsoleReadKey' -MockWith {
                    New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Enter, $false, $false, $false)
                }
            }
            It 'returns empty string' {
                $r = ConvertTo-MaskedInput -Prompt 'Password'
                $r | Should -Be ''
            }
        }

        Context 'ESC returns null' {
            BeforeEach {
                Mock -CommandName 'Invoke-ConsoleReadKey' -MockWith {
                    New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Escape, $false, $false, $false)
                }
            }
            It 'returns null' {
                $r = ConvertTo-MaskedInput -Prompt 'Password'
                $r | Should -BeNullOrEmpty
            }
        }

        Context 'Types 3 chars then Enter — returns plain string' {
            BeforeEach {
                $script:ki = 0
                $script:seq = @(
                    (New-Object System.ConsoleKeyInfo('a', [System.ConsoleKey]::A, $false, $false, $false)),
                    (New-Object System.ConsoleKeyInfo('b', [System.ConsoleKey]::B, $false, $false, $false)),
                    (New-Object System.ConsoleKeyInfo('c', [System.ConsoleKey]::C, $false, $false, $false)),
                    (New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Enter, $false, $false, $false))
                )
                Mock -CommandName 'Invoke-ConsoleReadKey' -MockWith {
                    $key = $script:seq[$script:ki]; $script:ki++; return $key
                }
            }
            It 'returns abc' {
                $r = ConvertTo-MaskedInput -Prompt 'P'
                $r | Should -Be 'abc'
            }
        }

        Context 'Backspace removes last char' {
            BeforeEach {
                $script:ki = 0
                $script:seq = @(
                    (New-Object System.ConsoleKeyInfo('x', [System.ConsoleKey]::X, $false, $false, $false)),
                    (New-Object System.ConsoleKeyInfo('y', [System.ConsoleKey]::Y, $false, $false, $false)),
                    (New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Backspace, $false, $false, $false)),
                    (New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Enter, $false, $false, $false))
                )
                Mock -CommandName 'Invoke-ConsoleReadKey' -MockWith {
                    $key = $script:seq[$script:ki]; $script:ki++; return $key
                }
                Mock -CommandName '[Console]::SetCursorPosition' -MockWith {} -ErrorAction SilentlyContinue
            }
            It 'returns x (y removed by backspace)' {
                $r = ConvertTo-MaskedInput -Prompt 'P'
                $r | Should -Be 'x'
            }
        }

        Context '-AsSecureString returns SecureString' {
            BeforeEach {
                $script:ki = 0
                $script:seq = @(
                    (New-Object System.ConsoleKeyInfo('s', [System.ConsoleKey]::S, $false, $false, $false)),
                    (New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Enter, $false, $false, $false))
                )
                Mock -CommandName 'Invoke-ConsoleReadKey' -MockWith {
                    $key = $script:seq[$script:ki]; $script:ki++; return $key
                }
            }
            It 'returns SecureString' {
                $r = ConvertTo-MaskedInput -Prompt 'P' -AsSecureString
                $r | Should -BeOfType [System.Security.SecureString]
            }
        }
    }
}
