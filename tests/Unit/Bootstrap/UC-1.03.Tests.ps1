#Requires -Modules Pester

Describe 'UC-1.03 - Force re-init bypasses initialized flag' -Tag 'Unit' {
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

    It 'prompts the user when -Force is given even though Initialized=$true' {
        InModuleScope TU-ACME {
            Mock Get-TUACMEConfig {
                [PSCustomObject]@{
                    Acme = [PSCustomObject]@{
                        ProdDirectoryUrl    = 'https://prod/dir'
                        StagingDirectoryUrl = 'https://staging/dir'
                        ContactEmail        = 'ops@example.com'
                        ProdAccountId       = 'acct-p'
                        StagingAccountId    = 'acct-s'
                        Initialized         = $true
                        InitializedAt       = '2026-01-01T00:00:00Z'
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

            $script:_ans = @('https://p.example/dir', 'https://s.example/dir', 'ops@example.com', 'n')
            $script:_idx = 0
            Mock Read-Host {
                $i = $script:_idx; $script:_idx = $i + 1
                return $script:_ans[$i]
            }

            Initialize-TUACMEEnvironment -Force

            Assert-MockCalled Read-Host -Times 1 -Scope It
        }
    }
}
