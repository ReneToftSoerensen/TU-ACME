#Requires -Modules Pester

Describe 'UC-1.09 - Create staging ACME account' -Tag 'Unit' {
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

    It 'calls Set-PAServer with staging URL and New-PAAccount -AcceptTOS' {
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
            Mock Set-TUACMEConfig {}
            Mock Invoke-ConsoleClear {}
            Mock Write-EventLogEntry {}
            Mock Show-Spinner { param($Message, $ScriptBlock, $Row) & $ScriptBlock }
            Mock Set-PAServer {}
            $script:_accCounter = 0
            Mock New-PAAccount {
                $script:_accCounter = $script:_accCounter + 1
                [PSCustomObject]@{ id = "acct-$($script:_accCounter)"; status = 'valid' }
            }
            Mock Get-PAAccount { [PSCustomObject]@{ id = 'acct-fallback'; status = 'valid' } }

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

            Assert-MockCalled Set-PAServer -ParameterFilter { $DirectoryUrl -eq 'https://staging.example/dir' } -Times 1 -Scope It
            # Two accounts total created (one prod, one staging)
            Assert-MockCalled New-PAAccount -Times 2 -Scope It
        }
    }
}
