#Requires -Modules Pester

Describe 'UC-1.02 - Skip wizard when already initialized' -Tag 'Unit' {
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

    It 'does not prompt or create accounts when Initialized=$true and -Force not given' {
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
            Mock Read-Host { 'should-not-be-called' }

            Initialize-TUACMEEnvironment

            Assert-MockCalled Read-Host    -Times 0 -Scope It
            Assert-MockCalled New-PAAccount -Times 0 -Scope It
        }
    }
}
