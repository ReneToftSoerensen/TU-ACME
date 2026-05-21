#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"
. "$PSScriptRoot\..\..\Fixtures\FakeObjects.ps1"

BeforeDiscovery { Import-TUACMEModule }

Describe 'Set-TUACMEConfig' -Tag Unit, Helpers {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        Context 'Writes JSON to config path' {
            BeforeEach {
                # Unconditional mocks - the previous ParameterFilter
                # ($Path -eq $script:cfgDir) never matched because the
                # production code uses $env:ProgramData\TU-ACME, not a
                # test-scoped path. Test-Path then ran for real against
                # whatever existed on disk and the assertion flapped
                # depending on whether TU-ACME was installed.
                Mock -CommandName 'Test-Path'    -MockWith { $false }
                Mock -CommandName 'New-Item'     -MockWith {}
                Mock -CommandName 'Set-Content'  -MockWith { $script:writtenContent = $Value }
            }

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
