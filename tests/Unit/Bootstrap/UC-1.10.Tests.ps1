#Requires -Modules Pester

Describe 'UC-1.10 - Persist config and log Event 1010' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force
        . "$PSScriptRoot\..\..\Fixtures\FakeObjects.ps1"
        Use-TUACMETempConfig
    }
    AfterAll {
        Restore-TUACMETempConfig
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'writes Initialized=$true with all fields and emits EventId 1010' {
        InModuleScope TU-ACME {
            Mock Get-TUACMEConfig {
                [PSCustomObject]@{
                    Acme = [PSCustomObject]@{
                        ProdDirectoryUrl    = ''
                        StagingDirectoryUrl = ''
                        ContactEmail        = ''
                        ProdAccountId       = ''
                        StagingAccountId    = ''
                        Initialized         = $false
                        InitializedAt       = ''
                    }
                }
            }
            $script:_persistedCfg = $null
            Mock Set-TUACMEConfig { param($Config) $script:_persistedCfg = $Config }
            Mock Invoke-ConsoleClear {}
            Mock Write-EventLogEntry {}
            Mock Show-Spinner { param($Message, $ScriptBlock, $Row) & $ScriptBlock }
            Mock Set-PAServer {}
            $script:_accCounter = 0
            Mock New-PAAccount {
                $script:_accCounter = $script:_accCounter + 1
                [PSCustomObject]@{ id = "acct-id-$($script:_accCounter)"; status = 'valid' }
            }
            Mock Get-PAAccount {}

            $script:_ans = @(
                'https://prod.example/dir',
                'https://staging.example/dir',
                'ops@example.com',
                'y',
                ''
            )
            $script:_idx = 0
            Mock Read-Host {
                $i = $script:_idx; $script:_idx = $i + 1
                return $script:_ans[$i]
            }

            Initialize-TUACMEEnvironment

            Assert-MockCalled Set-TUACMEConfig -Times 1 -Scope It
            Assert-MockCalled Write-EventLogEntry -ParameterFilter { $EventId -eq 1010 -and $EntryType -eq 'Information' } -Times 1 -Scope It

            $script:_persistedCfg                          | Should -Not -BeNullOrEmpty
            $script:_persistedCfg.Acme.Initialized         | Should -BeTrue
            $script:_persistedCfg.Acme.ProdDirectoryUrl    | Should -Be 'https://prod.example/dir'
            $script:_persistedCfg.Acme.StagingDirectoryUrl | Should -Be 'https://staging.example/dir'
            $script:_persistedCfg.Acme.ContactEmail        | Should -Be 'ops@example.com'
            $script:_persistedCfg.Acme.ProdAccountId       | Should -Be 'acct-id-1'
            $script:_persistedCfg.Acme.StagingAccountId    | Should -Be 'acct-id-2'
            $script:_persistedCfg.Acme.InitializedAt       | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$'
        }
    }
}
