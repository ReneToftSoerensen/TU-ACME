#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"

BeforeDiscovery { Import-TUACMEModule }

Describe 'Invoke-LogViewer' -Tag Unit, Logs {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        BeforeEach {
            Mock -CommandName 'Write-Host'            -MockWith {}
            Mock -CommandName 'Invoke-ConsoleClear'   -MockWith {}
            Mock -CommandName 'Invoke-ConsoleWaitKey' -MockWith {}
            Mock -CommandName 'Show-Menu'             -MockWith { 0 }
        }

        Context 'No log files found — shows message and returns' {
            BeforeEach {
                Mock -CommandName 'Get-ChildItem' -MockWith { @() }
            }
            It 'does not throw' {
                { Invoke-LogViewer } | Should -Not -Throw
            }
            It 'does not call Show-Menu' {
                Invoke-LogViewer
                Should -Invoke Show-Menu -Times 0
            }
        }

        Context 'One log file found — opens pager directly' {
            BeforeEach {
                $script:tmp = New-TempTestDir
                $script:logFile = Join-Path $script:tmp 'test.log'
                Set-Content -Path $script:logFile -Value @('Line 1', 'Line 2', 'Line 3')
                Mock -CommandName 'Get-ChildItem' -MockWith { @([System.IO.FileInfo]$script:logFile) }
                Mock -CommandName 'Get-Content'   -MockWith { @('Line 1', 'Line 2', 'Line 3') }
                Mock -CommandName 'Invoke-ConsoleReadKey' -MockWith {
                    New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Escape, $false, $false, $false)
                }
            }
            AfterEach { Remove-TempTestDir $script:tmp }

            It 'opens pager without throwing' {
                { Invoke-LogViewer } | Should -Not -Throw
            }
        }

        Context '_Show-LogPager — Get-Content fails gracefully' {
            BeforeEach {
                Mock -CommandName 'Get-Content' -MockWith { throw 'Permission denied' }
                Mock -CommandName 'Start-Sleep' -MockWith {}
            }
            It 'does not propagate exception' {
                { _Show-LogPager -LogFile 'C:\nonexistent.log' } | Should -Not -Throw
            }
        }

        Context '_Export-Log — copies file to destination' {
            BeforeEach {
                $script:tmp = New-TempTestDir
                $script:src = Join-Path $script:tmp 'source.log'
                Set-Content -Path $script:src -Value 'log content'
                $script:dst = Join-Path $script:tmp 'export.log'
                Mock -CommandName 'Read-Host'  -MockWith { $script:dst }
                Mock -CommandName 'Test-Path'  -MockWith { $false }
                Mock -CommandName 'Copy-Item'  -MockWith {}
                Mock -CommandName 'Start-Sleep' -MockWith {}
            }
            AfterEach { Remove-TempTestDir $script:tmp }

            It 'calls Copy-Item once' {
                _Export-Log -LogFile $script:src
                Should -Invoke Copy-Item -Times 1 -Exactly
            }
        }
    }
}
