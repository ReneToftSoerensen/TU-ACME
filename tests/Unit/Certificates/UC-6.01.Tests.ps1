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

    It 'renders Show-Menu with one option per Get-PAPlugin entry plus Back' {
        InModuleScope TU-ACME {
            Mock Invoke-ConsoleClear {}
            Mock Write-Host {}
            Mock Get-PAPlugin {
                @(
                    [PSCustomObject]@{ Name = 'Manual' },
                    [PSCustomObject]@{ Name = 'Route53' },
                    [PSCustomObject]@{ Name = 'Acme-Dns' }
                )
            }
            # Esc -> exit immediately
            Mock Show-Menu { return -1 }
            Mock Set-PAPluginArgs {}
            Mock Invoke-AcmeDnsSetup {}
            Mock Read-Host { return '' }

            Invoke-DnsPluginConfig

            Assert-MockCalled Show-Menu -Times 1 -Scope It -ParameterFilter {
                $Options -contains 'Manual' -and
                $Options -contains 'Route53' -and
                $Options -contains 'Acme-Dns' -and
                $Options[-1] -eq 'B. Back'
            }
        }
    }
}
