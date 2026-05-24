#Requires -Modules Pester

Describe 'UC-1.08 - Create prod ACME account' -Tag 'Unit' {
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

    It 'calls Set-PAServer with prod URL and New-PAAccount -AcceptTOS with the contact email' {
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
            # Show-Spinner mock that actually runs the scriptblock so we can
            # observe the Set-PAServer / New-PAAccount calls inside it.
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
                ''  # Press Enter to continue
            )
            $script:_idx = 0
            Mock Read-Host {
                $i = $script:_idx; $script:_idx = $i + 1
                return $script:_ans[$i]
            }

            Initialize-TUACMEEnvironment

            Assert-MockCalled Set-PAServer -ParameterFilter { $DirectoryUrl -eq 'https://prod.example/dir' } -Times 1 -Scope It
            Assert-MockCalled New-PAAccount -ParameterFilter { $Contact -eq 'ops@example.com' -and $AcceptTOS } -Times 1 -Scope It
        }
    }
}
