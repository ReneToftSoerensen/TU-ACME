#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"
. "$PSScriptRoot\..\..\Fixtures\FakeObjects.ps1"

Describe 'Send-TUACMEMail' -Tag Unit, Helpers {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        BeforeEach {
            Mock -CommandName 'Get-TUACMEConfig' -MockWith { New-FakeConfig }
            Mock -CommandName 'Send-MailMessage'  -MockWith {}
            Mock -CommandName 'Test-Path'         -MockWith { $false } -ParameterFilter { $Path -match 'smtp-credentials' }
        }

        Context 'No-auth send succeeds' {
            It 'returns true' {
                $r = Send-TUACMEMail -Subject 'Test' -Body 'Body'
                $r | Should -BeTrue
            }
            It 'calls Send-MailMessage once' {
                Send-TUACMEMail -Subject 'Test' -Body 'Body'
                Should -Invoke Send-MailMessage -Times 1 -Exactly
            }
        }

        Context 'Send-MailMessage throws' {
            BeforeEach {
                Mock -CommandName 'Send-MailMessage' -MockWith { throw 'SMTP connection refused' }
            }
            It 'returns false' {
                $r = Send-TUACMEMail -Subject 'Test' -Body 'Body'
                $r | Should -BeFalse
            }
            It 'does not propagate exception' {
                { Send-TUACMEMail -Subject 'Test' -Body 'Body' } | Should -Not -Throw
            }
        }

        Context 'Auth enabled — credential file exists' {
            BeforeEach {
                $authConfig = New-FakeConfig
                $authConfig.Email.UseAuth = $true
                Mock -CommandName 'Get-TUACMEConfig' -MockWith { $authConfig }
                Mock -CommandName 'Test-Path'        -MockWith { $true }  -ParameterFilter { $Path -match 'smtp-credentials' }
                $fakeStored = [PSCustomObject]@{
                    Username = 'user@test.dk'
                    Password = (ConvertTo-SecureString 'pass' -AsPlainText -Force)
                }
                Mock -CommandName 'Import-Clixml' -MockWith { $fakeStored }
            }
            It 'calls Send-MailMessage with Credential' {
                Send-TUACMEMail -Subject 'Auth' -Body 'x'
                Should -Invoke Send-MailMessage -Times 1 -Exactly
            }
        }

        Context 'Auth enabled — credential file missing' {
            BeforeEach {
                $authConfig = New-FakeConfig
                $authConfig.Email.UseAuth = $true
                Mock -CommandName 'Get-TUACMEConfig' -MockWith { $authConfig }
                Mock -CommandName 'Test-Path'        -MockWith { $false }
            }
            It 'still attempts send without credential' {
                Send-TUACMEMail -Subject 'Test' -Body 'x'
                Should -Invoke Send-MailMessage -Times 1 -Exactly
            }
        }

        Context 'Auth enabled — Import-Clixml throws' {
            BeforeEach {
                $authConfig = New-FakeConfig
                $authConfig.Email.UseAuth = $true
                Mock -CommandName 'Get-TUACMEConfig' -MockWith { $authConfig }
                Mock -CommandName 'Test-Path'        -MockWith { $true }
                Mock -CommandName 'Import-Clixml'    -MockWith { throw 'DPAPI error' }
            }
            It 'returns false without throwing' {
                { $r = Send-TUACMEMail -Subject 'x' -Body 'y'; $r | Should -BeFalse } | Should -Not -Throw
            }
        }
    }
}
