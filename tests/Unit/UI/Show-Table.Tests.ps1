#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"
. "$PSScriptRoot\..\..\Fixtures\FakeObjects.ps1"

Describe 'Show-Table' -Tag Unit, UI {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        BeforeEach {
            Mock -CommandName 'Write-Host'          -MockWith {}
            Mock -CommandName 'Invoke-ConsoleClear' -MockWith {}
        }

        $script:FakeCerts = @(
            New-FakeCertificate -Domain 'a.dk' -DaysLeft 60,
            New-FakeCertificate -Domain 'b.dk' -DaysLeft 20,
            (New-FakeExpiredCertificate)
        )

        Context 'Non-interactive — no return value' {
            It 'does not throw' {
                { Show-Table -Data $script:FakeCerts -Columns @('MainDomain', 'NotAfter') } | Should -Not -Throw
            }
            It 'returns nothing' {
                $r = Show-Table -Data $script:FakeCerts -Columns @('MainDomain')
                $r | Should -BeNullOrEmpty
            }
        }

        Context 'Empty dataset — returns -1' {
            It 'returns -1 without throwing' {
                $r = Show-Table -Data @() -Columns @('MainDomain') -Interactive
                $r | Should -Be -1
            }
        }

        Context 'Interactive — Enter on first row returns 0' {
            BeforeEach {
                $script:ki = 0
                $script:seq = @(
                    (New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Enter, $false, $false, $false))
                )
                Mock -CommandName 'Invoke-ConsoleReadKey' -MockWith {
                    $k = $script:seq[$script:ki]; $script:ki++; return $k
                }
            }
            It 'returns 0' {
                $r = Show-Table -Data $script:FakeCerts -Columns @('MainDomain') -Interactive
                $r | Should -Be 0
            }
        }

        Context 'Interactive — Down then Enter returns 1' {
            BeforeEach {
                $script:ki = 0
                $script:seq = @(
                    (New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::DownArrow, $false, $false, $false)),
                    (New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Enter, $false, $false, $false))
                )
                Mock -CommandName 'Invoke-ConsoleReadKey' -MockWith {
                    $k = $script:seq[$script:ki]; $script:ki++; return $k
                }
            }
            It 'returns 1' {
                $r = Show-Table -Data $script:FakeCerts -Columns @('MainDomain') -Interactive
                $r | Should -Be 1
            }
        }

        Context 'Interactive — ESC returns -1' {
            BeforeEach {
                Mock -CommandName 'Invoke-ConsoleReadKey' -MockWith {
                    New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Escape, $false, $false, $false)
                }
            }
            It 'returns -1' {
                $r = Show-Table -Data $script:FakeCerts -Columns @('MainDomain') -Interactive
                $r | Should -Be -1
            }
        }

        Context 'ColorRule is called per row' {
            It 'does not throw when ColorRule provided' {
                $rule = { param($row) 'Green' }
                { Show-Table -Data $script:FakeCerts -Columns @('MainDomain') -ColorRule $rule } | Should -Not -Throw
            }
        }
    }
}
