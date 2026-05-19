#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"
. "$PSScriptRoot\..\..\Fixtures\FakeObjects.ps1"

BeforeDiscovery { Import-TUACMEModule }

Describe 'Invoke-AccountMenu' -Tag Unit, Accounts {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        BeforeEach {
            Mock -CommandName 'Write-Host'         -MockWith {}
            Mock -CommandName 'Invoke-ConsoleClear' -MockWith {}
            Mock -CommandName 'Show-Table'         -MockWith {}
            Mock -CommandName 'Show-StatusBar'     -MockWith {}
            Mock -CommandName 'Get-PAAccount'      -MockWith { @(New-FakeAccount) }
            Mock -CommandName 'Set-PAAccount'      -MockWith {}
            Mock -CommandName 'Get-PAServer'       -MockWith { [PSCustomObject]@{ location = 'https://acme-v02.api.letsencrypt.org/directory' } }
            Mock -CommandName 'Set-PAServer'       -MockWith {}
            Mock -CommandName 'Invoke-ConsoleWaitKey' -MockWith {}
        }

        Context '_Toggle-StagingAccount — currently production, switches to staging' {
            It 'calls Set-PAServer with LE_STAGE' {
                _Toggle-StagingAccount
                Should -Invoke Set-PAServer -ParameterFilter { $DirectoryUrl -eq 'LE_STAGE' } -Times 1 -Exactly
            }
        }

        Context '_Toggle-StagingAccount — currently staging, switches to production' {
            BeforeEach {
                Mock -CommandName 'Get-PAServer' -MockWith {
                    [PSCustomObject]@{ location = 'https://acme-staging-v02.api.letsencrypt.org/directory' }
                }
            }
            It 'calls Set-PAServer with LE_PROD' {
                _Toggle-StagingAccount
                Should -Invoke Set-PAServer -Times 1 -Exactly
            }
        }

        Context '_Set-ActiveAccount — calls Set-PAAccount' {
            BeforeEach {
                $script:accounts = @(
                    (New-FakeAccount -Id 'acc-001')
                    (New-FakeAccount -Id 'acc-002')
                )
                Mock -CommandName 'Show-Menu' -MockWith { 0 }
            }
            It 'calls Set-PAAccount' {
                _Set-ActiveAccount -Accounts $script:accounts
                Should -Invoke Set-PAAccount -Times 1 -Exactly
            }
        }

        Context '_Set-ActiveAccount — ESC cancels without calling Set-PAAccount' {
            BeforeEach {
                Mock -CommandName 'Show-Menu' -MockWith { -1 }
            }
            It 'does not call Set-PAAccount' {
                _Set-ActiveAccount -Accounts @(New-FakeAccount)
                Should -Invoke Set-PAAccount -Times 0
            }
        }

        Context '_Set-ActiveAccount — empty accounts list' {
            BeforeEach {
                Mock -CommandName 'Start-Sleep' -MockWith {}
            }
            It 'does not call Set-PAAccount' {
                _Set-ActiveAccount -Accounts @()
                Should -Invoke Set-PAAccount -Times 0
            }
        }

        Context '_New-ACMEAccount — ESC on server selection returns without creating account' {
            BeforeEach {
                Mock -CommandName 'Read-Host'  -MockWith { 'admin@test.dk' }
                Mock -CommandName 'Show-Menu'  -MockWith { -1 }
                Mock -CommandName 'New-PAAccount' -MockWith {}
            }
            It 'does not call New-PAAccount' {
                _New-ACMEAccount
                Should -Invoke New-PAAccount -Times 0
            }
        }

        Context '_New-ACMEAccount — production server selected' {
            BeforeEach {
                Mock -CommandName 'Read-Host'     -MockWith { 'admin@test.dk' }
                Mock -CommandName 'Show-Menu'     -MockWith { 0 }
                Mock -CommandName 'Set-PAServer'  -MockWith {}
                Mock -CommandName 'New-PAAccount' -MockWith { [PSCustomObject]@{ id = 'new-001' } }
            }
            It 'calls New-PAAccount once' {
                _New-ACMEAccount
                Should -Invoke New-PAAccount -Times 1 -Exactly
            }
        }
    }
}
