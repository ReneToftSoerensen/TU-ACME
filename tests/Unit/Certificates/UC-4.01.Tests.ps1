#Requires -Modules Pester

Describe 'UC-4.01 - Dry-run uses staging then restores prod' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force
    }
    AfterAll {
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'calls Use-TUACMEStagingAccount before ordering and Use-TUACMEProdAccount in finally' {
        InModuleScope TU-ACME {
            Mock Invoke-ConsoleClear   {}
            Mock Use-TUACMEStagingAccount {}
            Mock Use-TUACMEProdAccount    {}
            Mock Get-PAPlugin             { @{ Name = 'FakePlugin' } }
            Mock Get-PAPluginArgs         { @{} }
            Mock New-PACertificate        { [PSCustomObject]@{ Thumbprint = 'AABBCC' } }
            Mock Set-PAOrder              {}
            Mock Show-Spinner             { param($Message, $ScriptBlock) & $ScriptBlock }
            Mock Write-EventLogEntry      {}

            $script:_ans = @(
                'dryrun.example.com',  # Domain
                '',                    # SANs
                'FakePlugin',          # Plugin
                'y'                    # Confirm
            )
            $script:_idx = 0
            Mock Read-Host {
                $i = $script:_idx; $script:_idx = $i + 1
                return $script:_ans[$i]
            }

            Invoke-DryRunOrder

            Assert-MockCalled Use-TUACMEStagingAccount -Times 1 -Scope It
            Assert-MockCalled Use-TUACMEProdAccount    -Times 1 -Scope It
        }
    }
}
