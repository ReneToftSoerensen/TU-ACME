#Requires -Modules Pester
Describe 'UC-6.04 - DNS plugin Acme-Dns picks dedicated helper' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc604-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'routes the Acme-Dns selection to Invoke-AcmeDnsSetup and skips the generic loop' {
        InModuleScope TU-ACME {
            Mock Invoke-ConsoleClear {}
            Mock Write-Host {}
            Mock Get-PAPlugin -ParameterFilter { -not $Plugin -and -not $Params } -MockWith {
                @(
                    [PSCustomObject]@{ Name = 'Manual';   ChallengeType = 'dns-01' },
                    [PSCustomObject]@{ Name = 'Acme-Dns'; ChallengeType = 'dns-01' }
                )
            }
            # The generic param loop would call Get-PAPlugin -Plugin <name> -Params; track it.
            Mock Get-PAPlugin -ParameterFilter { $Plugin -and $Params } -MockWith { @() }

            # Tier picker -> DNS-01 (0). Plugin picker -> Acme-Dns; after sort
            # the order is [Acme-Dns, Manual] so Acme-Dns is at index 0.
            Mock Show-Menu { return 0 }
            Mock Export-Clixml {}
            Mock Invoke-AcmeDnsSetup {}
            Mock Read-Host { return '' }

            Invoke-DnsPluginConfig

            Assert-MockCalled Invoke-AcmeDnsSetup -Times 1 -Scope It
            # Generic loop must not run for Acme-Dns: no Get-PAPlugin -Params call.
            Assert-MockCalled Get-PAPlugin -Times 0 -Scope It -Exactly -ParameterFilter {
                $Plugin -and $Params
            }
            # And Set-PAPluginArgs must not run either: the helper owns persistence.
            Assert-MockCalled Export-Clixml -Times 0 -Scope It -Exactly
        }
    }
}
