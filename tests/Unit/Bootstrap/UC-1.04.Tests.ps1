#Requires -Modules Pester

Describe 'UC-1.04 - Prompt and validate prod directory URL' -Tag 'Unit' {
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

    It 'rejects non-https URL and re-prompts until https is given' {
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

            # First prod attempt invalid, then valid; staging valid; valid email; cancel.
            $script:_ans = @(
                'http://bad',
                'https://acme.corp/dir',
                'https://staging.corp/dir',
                'ops@example.com',
                'n'
            )
            $script:_idx = 0
            $script:_prodPromptCount = 0
            Mock Read-Host {
                param([string] $Prompt)
                if ($Prompt -eq 'Prod ACME directory URL') {
                    $script:_prodPromptCount = $script:_prodPromptCount + 1
                }
                $i = $script:_idx; $script:_idx = $i + 1
                return $script:_ans[$i]
            }

            Initialize-TUACMEEnvironment

            $script:_prodPromptCount | Should -BeGreaterOrEqual 2
        }
    }
}
