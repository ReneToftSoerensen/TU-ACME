#Requires -Modules Pester

Describe 'UC-1.01 - Detect uninitialized config triggers wizard' -Tag 'Unit' {
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

    It 'invokes the wizard (prompts at least once) when Initialized=$false' {
        InModuleScope TU-ACME {
            # Force a fresh, uninitialized config
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
            Mock Show-Spinner {}
            Mock Set-PAServer {}
            Mock New-PAAccount { [PSCustomObject]@{ id = 'acct-1'; status = 'valid' } }
            Mock Get-PAAccount { [PSCustomObject]@{ id = 'acct-1'; status = 'valid' } }

            # Cancel at confirmation to keep the test minimal (no accounts created)
            $script:_ans = @('https://prod.example/dir', 'https://staging.example/dir', 'ops@example.com', 'n')
            $script:_idx = 0
            Mock Read-Host {
                $i = $script:_idx; $script:_idx = $i + 1
                return $script:_ans[$i]
            }

            Initialize-TUACMEEnvironment

            Assert-MockCalled Read-Host -Times 1 -Scope It
        }
    }
}
