#Requires -Modules Pester
Describe 'UC-6.01 - DNS plugin menu lists Get-PAPlugin entries' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc601-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'renders the second-tier Show-Menu with one option per DNS-01 plugin plus Back' {
        InModuleScope TU-ACME {
            Mock Invoke-ConsoleClear {}
            Mock Write-Host {}
            Mock Get-PAPlugin {
                @(
                    [PSCustomObject]@{ Name = 'Manual';   ChallengeType = 'dns-01' },
                    [PSCustomObject]@{ Name = 'Route53';  ChallengeType = 'dns-01' },
                    [PSCustomObject]@{ Name = 'Acme-Dns'; ChallengeType = 'dns-01' }
                )
            }
            # First Show-Menu call (tier picker): pick DNS-01 (index 0).
            # Second Show-Menu call (plugin picker): -1 to bail out.
            Mock Show-Menu { return 0 }, { return -1 }
            Mock Export-Clixml {}
            Mock Invoke-AcmeDnsSetup {}
            Mock Read-Host { return '' }

            Invoke-DnsPluginConfig

            # Tier picker: 3 challenge-type buckets + Back.
            Assert-MockCalled Show-Menu -Times 1 -Scope It -ParameterFilter {
                $Options.Count -eq 4 -and
                $Options[0] -match 'DNS-01' -and
                $Options[-1] -eq 'B. Back'
            }
            # Plugin picker: every plugin name plus Back, ordered alphabetically.
            Assert-MockCalled Show-Menu -Times 1 -Scope It -ParameterFilter {
                $Options -contains 'Manual' -and
                $Options -contains 'Route53' -and
                $Options -contains 'Acme-Dns' -and
                $Options[-1] -eq 'B. Back'
            }
        }
    }
}
