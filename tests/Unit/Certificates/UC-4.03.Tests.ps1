#Requires -Modules Pester

Describe 'UC-4.03 - Dry-run tags issued cert as TU-ACME-DryRun' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force
    }
    AfterAll {
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'tags the order TU-ACME-DryRun and emits Event 1006 on success' {
        InModuleScope TU-ACME {
            Mock Invoke-ConsoleClear      {}
            Mock Use-TUACMEStagingAccount {}
            Mock Use-TUACMEProdAccount    {}
            Mock Get-PAPlugin             { @{ Name = 'FakePlugin' } }
            Mock Get-PAPluginArgs         { @{} }
            Mock New-PACertificate        { [PSCustomObject]@{ Thumbprint = 'DEADBEEF' } }
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

            Assert-MockCalled Set-PAOrder `
                -ParameterFilter { $FriendlyName -eq 'TU-ACME-DryRun' } `
                -Times 1 -Exactly -Scope It
            Assert-MockCalled Write-EventLogEntry `
                -ParameterFilter { $EventId -eq 1006 } `
                -Times 1 -Exactly -Scope It
        }
    }
}
