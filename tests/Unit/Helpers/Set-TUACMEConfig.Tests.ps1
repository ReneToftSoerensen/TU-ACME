#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"
. "$PSScriptRoot\..\..\Fixtures\FakeObjects.ps1"

Describe 'Set-TUACMEConfig' -Tag Unit, Helpers {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        Context 'Writes JSON to config path' {
            BeforeEach {
                $script:tmp       = New-TempTestDir
                $script:cfgDir    = Join-Path $script:tmp 'TU-ACME'
                $script:cfgPath   = Join-Path $script:cfgDir 'config.json'
                Mock -CommandName 'Test-Path'    -MockWith { $false } -ParameterFilter { $Path -eq $script:cfgDir }
                Mock -CommandName 'New-Item'     -MockWith {}
                Mock -CommandName 'Set-Content'  -MockWith { $script:writtenContent = $Value }
            }
            AfterEach { Remove-TempTestDir $script:tmp }

            It 'calls Set-Content once' {
                Set-TUACMEConfig -Config (New-FakeConfig)
                Should -Invoke Set-Content -Times 1 -Exactly
            }
            It 'creates config directory if missing' {
                Set-TUACMEConfig -Config (New-FakeConfig)
                Should -Invoke New-Item -Times 1 -Exactly
            }
            It 'written JSON is parseable' {
                Set-TUACMEConfig -Config (New-FakeConfig)
                { $script:writtenContent | ConvertFrom-Json } | Should -Not -Throw
            }
        }

        Context 'Directory already exists' {
            BeforeEach {
                Mock -CommandName 'Test-Path'   -MockWith { $true }
                Mock -CommandName 'New-Item'    -MockWith {}
                Mock -CommandName 'Set-Content' -MockWith {}
            }

            It 'does not call New-Item' {
                Set-TUACMEConfig -Config (New-FakeConfig)
                Should -Invoke New-Item -Times 0
            }
        }
    }
}
