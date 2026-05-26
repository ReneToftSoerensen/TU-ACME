#Requires -Modules Pester
Describe 'UC-6.07 - Plugin menu uses two-tier flow with AllowSearch' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc607-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'first tier has exactly four options and second tier is called with AllowSearch' {
        InModuleScope TU-ACME {
            Mock Invoke-ConsoleClear {}
            Mock Write-Host {}
            Mock Get-PAPlugin -RemoveParameterValidation 'Plugin' -ParameterFilter { -not $Plugin -and -not $Params } -MockWith {
                @(
                    [PSCustomObject]@{ Name = 'Manual';  ChallengeType = 'dns-01' },
                    [PSCustomObject]@{ Name = 'Route53'; ChallengeType = 'dns-01' }
                )
            }
            # Tier picker -> DNS-01 (0). Second tier: -1 to bail.
            $script:_uc607_calls = 0
            Mock Show-Menu {
                $i = $script:_uc607_calls
                $script:_uc607_calls = $i + 1
                if ($i -eq 0) { return 0 } else { return -1 }
            }
            Mock Export-Clixml {}
            Mock Invoke-AcmeDnsSetup {}
            Mock Read-Host { return '' }

            Invoke-DnsPluginConfig

            # First-tier menu: exactly 4 options, three challenge-type buckets + Back.
            Assert-MockCalled Show-Menu -Times 1 -Scope It -ParameterFilter {
                $Options.Count -eq 4 -and
                $Options[0] -match 'DNS-01' -and
                $Options[1] -match 'persistent' -and
                $Options[2] -match 'HTTP-01' -and
                $Options[-1] -eq 'B. Back' -and
                -not $AllowSearch
            }
            # Second-tier menu: AllowSearch is set.
            Assert-MockCalled Show-Menu -Times 1 -Scope It -ParameterFilter {
                $AllowSearch -eq $true
            }
        }
    }
}
