#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"
. "$PSScriptRoot\..\..\Fixtures\FakeObjects.ps1"

Describe 'Get-TUACMEConfig' -Tag Unit, Helpers {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        Context 'No config file — returns defaults' {
            BeforeEach {
                $script:tmp = New-TempTestDir
                Mock -CommandName 'Test-Path' -MockWith { $false } -ParameterFilter { $Path -match 'config\.json' }
            }
            AfterEach { Remove-TempTestDir $script:tmp }

            It 'returns a PSCustomObject' {
                $r = Get-TUACMEConfig
                $r | Should -BeOfType [PSCustomObject]
            }
            It 'default DnsSleep is 120' {
                (Get-TUACMEConfig).DNS.DefaultDnsSleep | Should -Be 120
            }
            It 'default ValidationTimeout is 60' {
                (Get-TUACMEConfig).DNS.DefaultValidationTimeout | Should -Be 60
            }
            It 'default PersistentRecords is false' {
                (Get-TUACMEConfig).DNS.PersistentRecords | Should -BeFalse
            }
            It 'default SMTP port is 587' {
                (Get-TUACMEConfig).Email.SmtpPort | Should -Be 587
            }
            It 'default WarnDaysThreshold is 30' {
                (Get-TUACMEConfig).Dashboard.WarnDaysThreshold | Should -Be 30
            }
        }

        Context 'Valid config file' {
            BeforeEach {
                $script:tmp = New-TempTestDir
                $script:cfgPath = Join-Path $script:tmp 'config.json'
                $json = '{"Version":"1.0","Email":{"SmtpPort":465},"Dashboard":{"WarnDaysThreshold":14},"DNS":{"DefaultDnsSleep":300,"DefaultValidationTimeout":90,"PersistentRecords":true}}'
                Set-Content -Path $script:cfgPath -Value $json -Encoding UTF8
                Mock -CommandName 'Test-Path'       -MockWith { $true }  -ParameterFilter { $Path -match 'config\.json' }
                Mock -CommandName 'Get-Content'     -MockWith { $json }  -ParameterFilter { $Path -match 'config\.json' }
            }
            AfterEach { Remove-TempTestDir $script:tmp }

            It 'reads SmtpPort from file' {
                (Get-TUACMEConfig).Email.SmtpPort | Should -Be 465
            }
            It 'reads WarnDaysThreshold from file' {
                (Get-TUACMEConfig).Dashboard.WarnDaysThreshold | Should -Be 14
            }
            It 'reads DNS DnsSleep from file' {
                (Get-TUACMEConfig).DNS.DefaultDnsSleep | Should -Be 300
            }
            It 'reads PersistentRecords true from file' {
                (Get-TUACMEConfig).DNS.PersistentRecords | Should -BeTrue
            }
        }

        Context 'Malformed config file — falls back to defaults' {
            BeforeEach {
                Mock -CommandName 'Test-Path'   -MockWith { $true } -ParameterFilter { $Path -match 'config\.json' }
                Mock -CommandName 'Get-Content' -MockWith { 'NOT_VALID_JSON{{{' } -ParameterFilter { $Path -match 'config\.json' }
            }

            It 'does not throw' {
                { Get-TUACMEConfig } | Should -Not -Throw
            }
            It 'returns default DnsSleep on parse error' {
                (Get-TUACMEConfig).DNS.DefaultDnsSleep | Should -Be 120
            }
        }
    }
}
