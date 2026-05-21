#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"
. "$PSScriptRoot\..\..\Fixtures\FakeObjects.ps1"

BeforeDiscovery { Import-TUACMEModule }

Describe 'Invoke-AccountMenu' -Tag Unit, Accounts {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        BeforeEach {
            Mock -CommandName 'Write-Host'            -MockWith {}
            Mock -CommandName 'Invoke-ConsoleClear'   -MockWith {}
            Mock -CommandName 'Show-Table'            -MockWith {}
            Mock -CommandName 'Show-StatusBar'        -MockWith {}
            Mock -CommandName 'Get-PAAccount'         -MockWith { @(New-FakeAccount) }
            Mock -CommandName 'Set-PAAccount'         -MockWith {}
            Mock -CommandName 'Get-PAServer'          -MockWith { [PSCustomObject]@{ location = 'https://acme-v02.api.letsencrypt.org/directory' } }
            Mock -CommandName 'Set-PAServer'          -MockWith {}
            Mock -CommandName 'Invoke-ConsoleWaitKey' -MockWith {}
            Mock -CommandName 'Get-TUACMEConfig'      -MockWith { New-FakeConfig }
            Mock -CommandName 'Set-TUACMEConfig'      -MockWith {}
            Mock -CommandName 'Start-Sleep'           -MockWith {}
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
                $script:ri = 0
                $script:rseq = @('admin@test.dk', 'Production')  # email, friendly name
                Mock -CommandName 'Read-Host'     -MockWith { $r = $script:rseq[$script:ri]; $script:ri++; $r }
                Mock -CommandName 'Show-Menu'     -MockWith { 0 }
                Mock -CommandName 'Set-PAServer'  -MockWith {}
                Mock -CommandName 'New-PAAccount' -MockWith { [PSCustomObject]@{ id = 'new-001' } }
            }
            It 'calls New-PAAccount once' {
                _New-ACMEAccount
                Should -Invoke New-PAAccount -Times 1 -Exactly
            }
            It 'persists the friendly name via Set-TUACMEConfig' {
                _New-ACMEAccount
                Should -Invoke Set-TUACMEConfig -Times 1 -Exactly
            }
        }

        Context '_New-ACMEAccount — blank friendly name skips Set-TUACMEConfig' {
            BeforeEach {
                $script:ri = 0
                $script:rseq = @('admin@test.dk', '')   # email, blank name
                Mock -CommandName 'Read-Host'     -MockWith { $r = $script:rseq[$script:ri]; $script:ri++; $r }
                Mock -CommandName 'Show-Menu'     -MockWith { 0 }
                Mock -CommandName 'New-PAAccount' -MockWith { [PSCustomObject]@{ id = 'new-002' } }
            }
            It 'does not call Set-TUACMEConfig' {
                _New-ACMEAccount
                Should -Invoke Set-TUACMEConfig -Times 0
            }
        }

        Context '_Set-ActiveAccount — same account is already active, skips Set-PAAccount' {
            BeforeEach {
                $script:accounts = @((New-FakeAccount -Id 'acc-001'), (New-FakeAccount -Id 'acc-002'))
                Mock -CommandName 'Show-Menu' -MockWith { 0 }
            }
            It 'does not call Set-PAAccount when picked equals ActiveId' {
                _Set-ActiveAccount -Accounts $script:accounts -ActiveId 'acc-001'
                Should -Invoke Set-PAAccount -Times 0
            }
            It 'does call Set-PAAccount when picked differs from ActiveId' {
                _Set-ActiveAccount -Accounts $script:accounts -ActiveId 'acc-002'
                Should -Invoke Set-PAAccount -Times 1 -Exactly
            }
        }

        Context '_Rename-Account — saves new name' {
            BeforeEach {
                $script:accounts = @((New-FakeAccount -Id 'acc-001'))
                Mock -CommandName 'Show-Menu' -MockWith { 0 }
                Mock -CommandName 'Read-Host' -MockWith { 'New Friendly Name' }
            }
            It 'calls Set-TUACMEConfig once' {
                _Rename-Account -Accounts $script:accounts
                Should -Invoke Set-TUACMEConfig -Times 1 -Exactly
            }
        }

        Context '_Get-AccountFriendlyName — lookup by id' {
            It 'returns the Name when id is present' {
                $map = [PSCustomObject]@{}
                $map | Add-Member -NotePropertyName 'acc-001' -NotePropertyValue ([PSCustomObject]@{ Name = 'Production' })
                _Get-AccountFriendlyName -Id 'acc-001' -Map $map | Should -Be 'Production'
            }
            It 'returns empty string when id missing' {
                $map = [PSCustomObject]@{}
                _Get-AccountFriendlyName -Id 'acc-999' -Map $map | Should -BeNullOrEmpty
            }
            It 'returns empty string when map is null' {
                _Get-AccountFriendlyName -Id 'acc-001' -Map $null | Should -BeNullOrEmpty
            }
        }
    }
}
