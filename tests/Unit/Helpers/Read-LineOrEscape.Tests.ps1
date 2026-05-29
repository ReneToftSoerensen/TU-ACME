#Requires -Modules Pester
Describe 'Read-LineOrEscape' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force
    }

    AfterAll {
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'returns $null when Escape is the first key pressed' {
        InModuleScope TU-ACME {
            Mock Test-InteractiveConsole { $true }
            Mock Get-ConsoleCursorLeft   { 0 }
            Mock Get-ConsoleCursorTop    { 0 }
            Mock Set-ConsoleCursorPos    {}
            Mock Set-ConsoleCursorVisible {}
            Mock Write-Host              {}

            $script:_rleKeys = @(
                [System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::Escape, $false, $false, $false)
            )
            $script:_rleIdx = 0
            Mock Invoke-ConsoleReadKey {
                $k = $script:_rleKeys[$script:_rleIdx]
                $script:_rleIdx = $script:_rleIdx + 1
                return $k
            }

            $result = Read-LineOrEscape -Prompt 'Test'
            ($null -eq $result) | Should -BeTrue
        }
    }

    It 'returns the accumulated string when Enter terminates the line' {
        InModuleScope TU-ACME {
            Mock Test-InteractiveConsole { $true }
            Mock Get-ConsoleCursorLeft   { 0 }
            Mock Get-ConsoleCursorTop    { 0 }
            Mock Set-ConsoleCursorPos    {}
            Mock Set-ConsoleCursorVisible {}
            Mock Write-Host              {}

            $script:_rleKeys = @(
                [System.ConsoleKeyInfo]::new('h', [ConsoleKey]::H,     $false, $false, $false),
                [System.ConsoleKeyInfo]::new('i', [ConsoleKey]::I,     $false, $false, $false),
                [System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::Enter, $false, $false, $false)
            )
            $script:_rleIdx = 0
            Mock Invoke-ConsoleReadKey {
                $k = $script:_rleKeys[$script:_rleIdx]
                $script:_rleIdx = $script:_rleIdx + 1
                return $k
            }

            $result = Read-LineOrEscape -Prompt 'Test'
            $result | Should -Be 'hi'
        }
    }

    It 'returns an empty string on bare Enter' {
        InModuleScope TU-ACME {
            Mock Test-InteractiveConsole { $true }
            Mock Get-ConsoleCursorLeft   { 0 }
            Mock Get-ConsoleCursorTop    { 0 }
            Mock Set-ConsoleCursorPos    {}
            Mock Set-ConsoleCursorVisible {}
            Mock Write-Host              {}

            $script:_rleKeys = @(
                [System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::Enter, $false, $false, $false)
            )
            $script:_rleIdx = 0
            Mock Invoke-ConsoleReadKey {
                $k = $script:_rleKeys[$script:_rleIdx]
                $script:_rleIdx = $script:_rleIdx + 1
                return $k
            }

            $result = Read-LineOrEscape -Prompt 'Test'
            $result | Should -Be ''
        }
    }

    It 'falls back to Read-Host on a non-interactive console' {
        InModuleScope TU-ACME {
            Mock Test-InteractiveConsole { $false }
            Mock Read-Host               { 'fallback-value' }
            Mock Invoke-ConsoleReadKey   { throw 'should not be called' }

            $result = Read-LineOrEscape -Prompt 'Test'
            $result | Should -Be 'fallback-value'
            Assert-MockCalled Read-Host -Times 1 -Scope It
            Assert-MockCalled Invoke-ConsoleReadKey -Times 0 -Scope It
        }
    }
}
