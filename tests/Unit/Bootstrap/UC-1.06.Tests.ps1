#Requires -Modules Pester

Describe 'UC-1.06 - Prompt and validate contact email' -Tag 'Unit' {
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

    It 'rejects malformed email and re-prompts until a valid address is given' {
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
            Mock Show-Spinner {}
            Mock Set-PAServer {}
            Mock New-PAAccount {}
            Mock Get-PAAccount {}

            $script:_ans = @(
                'https://acme.corp/dir',
                'https://staging.corp/dir',
                'not-an-email',
                'ops@example.com',
                'n'
            )
            $script:_idx = 0
            $script:_emailPromptCount = 0
            Mock Read-Host {
                param([string] $Prompt)
                if ($Prompt -eq 'Contact email') {
                    $script:_emailPromptCount = $script:_emailPromptCount + 1
                }
                $i = $script:_idx; $script:_idx = $i + 1
                return $script:_ans[$i]
            }

            Initialize-TUACMEEnvironment

            $script:_emailPromptCount | Should -BeGreaterOrEqual 2
        }
    }
}
