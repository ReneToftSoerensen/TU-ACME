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

        Context '_New-ACMEAccount — New-PAAccount returns the account directly (Posh-ACME 4.32+)' {
            # The happy path: capture the return value of New-PAAccount
            # as the primary source. No need to consult Get-PAAccount.
            BeforeEach {
                $script:ri = 0
                $script:rseq = @('admin@test.dk', 'Production')  # email, friendly name
                Mock -CommandName 'Read-Host'     -MockWith { $r = $script:rseq[$script:ri]; $script:ri++; $r }
                Mock -CommandName 'Show-Menu'     -MockWith { 0 }
                Mock -CommandName 'Set-PAServer'  -MockWith {}
                Mock -CommandName 'New-PAAccount' -MockWith {
                    [PSCustomObject]@{ id = 'returned-001'; status = 'valid' }
                }
            }
            It 'activates the account using the New-PAAccount return value' {
                _New-ACMEAccount
                Should -Invoke Set-PAAccount -ParameterFilter { $ID -eq 'returned-001' } -Times 1 -Exactly
            }
            It 'does not fall back to Get-PAAccount when the return is non-null' {
                _New-ACMEAccount
                Should -Invoke Get-PAAccount -Times 0
            }
            It 'persists the friendly name via Set-TUACMEConfig' {
                _New-ACMEAccount
                Should -Invoke Set-TUACMEConfig -Times 1 -Exactly
            }
        }

        Context '_New-ACMEAccount — New-PAAccount returns null, Get-PAAccount has the new account' {
            # Posh-ACME versions where the return is $null but the
            # current-account pointer IS set. Use the current pointer.
            BeforeEach {
                $script:ri = 0
                $script:rseq = @('admin@test.dk', 'Production')
                Mock -CommandName 'Read-Host'     -MockWith { $r = $script:rseq[$script:ri]; $script:ri++; $r }
                Mock -CommandName 'Show-Menu'     -MockWith { 0 }
                Mock -CommandName 'Set-PAServer'  -MockWith {}
                Mock -CommandName 'New-PAAccount' -MockWith { $null }
                Mock -CommandName 'Get-PAAccount' -ParameterFilter { -not $List } `
                    -MockWith { [PSCustomObject]@{ id = 'current-001'; status = 'valid' } }
            }
            It 'falls back to Get-PAAccount and activates its account' {
                _New-ACMEAccount
                Should -Invoke Set-PAAccount -ParameterFilter { $ID -eq 'current-001' } -Times 1 -Exactly
            }
        }

        Context '_New-ACMEAccount — both New-PAAccount and Get-PAAccount return nothing' {
            # Only here should we surface the failure to the user.
            BeforeEach {
                Mock -CommandName 'Read-Host'     -MockWith { 'admin@test.dk' }
                Mock -CommandName 'Show-Menu'     -MockWith { 0 }
                Mock -CommandName 'New-PAAccount' -MockWith { $null }
                Mock -CommandName 'Get-PAAccount' -MockWith { $null }
            }
            It 'does not call Set-PAAccount' {
                _New-ACMEAccount
                Should -Invoke Set-PAAccount -Times 0
            }
            It 'does not call Set-TUACMEConfig' {
                _New-ACMEAccount
                Should -Invoke Set-TUACMEConfig -Times 0
            }
        }

        Context '_New-ACMEAccount — New-PAAccount throws (-ErrorAction Stop catches non-terminating errors)' {
            # Earlier versions did "New-PAAccount ... | Out-Null" without
            # -ErrorAction Stop, which swallowed non-terminating errors
            # like invalid contact / server unreachable and surfaced a
            # generic "appears to have failed" with no useful detail.
            BeforeEach {
                Mock -CommandName 'Read-Host'     -MockWith { 'admin@test.dk' }
                Mock -CommandName 'Show-Menu'     -MockWith { 0 }
                Mock -CommandName 'New-PAAccount' -MockWith { throw 'urn:ietf:params:acme:error:malformed: contact must be valid' }
            }
            It 'does not call Set-PAAccount when New-PAAccount throws' {
                _New-ACMEAccount
                Should -Invoke Set-PAAccount -Times 0
            }
            It 'does not call Set-TUACMEConfig when New-PAAccount throws' {
                _New-ACMEAccount
                Should -Invoke Set-TUACMEConfig -Times 0
            }
        }

        Context '_New-ACMEAccount — Get-PAAccount returns null but -List has a valid account' {
            # Two pointers above are null; the last resort is "most
            # recently added valid account on this server". Filter is
            # on status='valid' (NOT contact) because LE Staging does
            # not echo contact back in the account object.
            BeforeEach {
                $script:ri = 0
                $script:rseq = @('admin@test.dk', '')
                Mock -CommandName 'Read-Host'     -MockWith { $r = $script:rseq[$script:ri]; $script:ri++; $r }
                Mock -CommandName 'Show-Menu'     -MockWith { 0 }
                Mock -CommandName 'New-PAAccount' -MockWith { $null }
                Mock -CommandName 'Get-PAAccount' -ParameterFilter { $List } `
                    -MockWith {
                        @(
                            [PSCustomObject]@{ id = 'old-deactivated'; contact = $null; status = 'deactivated' }
                            [PSCustomObject]@{ id = 'list-only-001';   contact = $null; status = 'valid' }
                        )
                    }
                Mock -CommandName 'Get-PAAccount' -ParameterFilter { -not $List } `
                    -MockWith { $null }
            }
            It 'finds the valid account via -List (ignoring contact, ignoring deactivated)' {
                _New-ACMEAccount
                Should -Invoke Set-PAAccount -ParameterFilter { $ID -eq 'list-only-001' } -Times 1 -Exactly
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

        Context 'Create-then-rename flow — newly created account is renameable' {
            # Reproduces the user-reported bug: after creating an account,
            # picking "Rename" said "No accounts to rename". Root cause was
            # Posh-ACME leaving the previous server's account selected so
            # Get-PAAccount -List returned [] on the just-switched server.
            BeforeEach {
                # Simulate Posh-ACME's state: -List returns [] before any
                # account exists; New-PAAccount creates 'new-001'; -List
                # then returns it.
                $script:createdId = $null
                Mock -CommandName 'Get-PAAccount' -MockWith {
                    if ($PSBoundParameters.ContainsKey('List')) {
                        if ($script:createdId) { return @([PSCustomObject]@{ id = $script:createdId; contact = 'mailto:admin@test.dk'; status = 'valid' }) }
                        return @()
                    }
                    if ($script:createdId) { return [PSCustomObject]@{ id = $script:createdId; contact = 'mailto:admin@test.dk'; status = 'valid' } }
                    return $null
                }
                Mock -CommandName 'New-PAAccount' -MockWith {
                    $script:createdId = 'new-001'
                    [PSCustomObject]@{ id = 'new-001' }
                }
                Mock -CommandName 'Set-PAAccount' -MockWith {}
                Mock -CommandName 'Set-PAServer'  -MockWith {}

                $script:ri = 0
                $script:rseq = @('admin@test.dk', 'My new account', 'Renamed account')
                Mock -CommandName 'Read-Host' -MockWith { $r = $script:rseq[$script:ri]; $script:ri++; $r }
                Mock -CommandName 'Show-Menu' -MockWith { 0 }   # production server, then first account in rename list
            }

            It 'lists the new account after create' {
                Get-PAAccount -List | Should -BeNullOrEmpty
                _New-ACMEAccount
                $listed = @(Get-PAAccount -List)
                $listed.Count   | Should -Be 1
                $listed[0].id   | Should -Be 'new-001'
            }

            It 'Rename succeeds on the just-created account (no "No accounts" message)' {
                _New-ACMEAccount
                $accounts = @(Get-PAAccount -List)
                _Rename-Account -Accounts $accounts
                Should -Invoke Set-TUACMEConfig -ParameterFilter {
                    $Config.Accounts.PSObject.Properties['new-001'].Value.Name -eq 'Renamed account'
                } -Times 1
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
