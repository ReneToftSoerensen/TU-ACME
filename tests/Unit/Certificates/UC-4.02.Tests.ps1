#Requires -Modules Pester

Describe 'UC-4.02 - Dry-run restores prod even when ordering fails' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force
    }
    AfterAll {
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'still calls Use-TUACMEProdAccount when New-PACertificate throws' {
        InModuleScope TU-ACME {
            Mock Invoke-ConsoleClear      {}
            Mock Use-TUACMEStagingAccount {}
            Mock Use-TUACMEProdAccount    {}
            Mock Get-PAPlugin             { @{ Name = 'FakePlugin' } }
            Mock Get-PAPluginArgs         { @{} }
            Mock New-PACertificate        { throw 'boom' }
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

            # Invoke should not throw out — the function catches and reports
            Invoke-DryRunOrder

            Assert-MockCalled Use-TUACMEStagingAccount -Times 1 -Scope It
            Assert-MockCalled Use-TUACMEProdAccount    -Times 1 -Scope It
            Assert-MockCalled Set-PAOrder              -Times 0 -Scope It
            Assert-MockCalled Write-EventLogEntry      -Times 0 -Scope It
        }
    }
}
