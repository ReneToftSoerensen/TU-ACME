#Requires -Modules Pester
Describe 'UC-6.05 - Plugin menu offers HTTP-01 filter' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc605-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'second-tier Show-Menu contains only http-01 plugins when HTTP-01 bucket is picked' {
        InModuleScope TU-ACME {
            Mock Invoke-ConsoleClear {}
            Mock Write-Host {}
            Mock Get-PAPlugin -RemoveParameterValidation 'Plugin' -ParameterFilter { -not $Plugin -and -not $Params } -MockWith {
                @(
                    [PSCustomObject]@{ Name = 'Manual';      ChallengeType = 'dns-01' },
                    [PSCustomObject]@{ Name = 'Route53';     ChallengeType = 'dns-01' },
                    [PSCustomObject]@{ Name = 'WebRoot';     ChallengeType = 'http-01' },
                    [PSCustomObject]@{ Name = 'WebSelfHost'; ChallengeType = 'http-01' }
                )
            }
            # Tier picker -> HTTP-01 (index 2). Second tier: -1 to bail before
            # the param loop runs.
            $script:_uc605_calls = 0
            Mock Show-Menu {
                $i = $script:_uc605_calls
                $script:_uc605_calls = $i + 1
                if ($i -eq 0) { return 2 } else { return -1 }
            }
            Mock Export-Clixml {}
            Mock Invoke-AcmeDnsSetup {}
            Mock Read-Host { return '' }

            Invoke-DnsPluginConfig

            # Second-tier menu must have exactly the two HTTP-01 plugins (+ Back),
            # and no DNS-01 plugin.
            Assert-MockCalled Show-Menu -Times 1 -Scope It -ParameterFilter {
                $Title -match 'HTTP-01' -and
                $Options -contains 'WebRoot' -and
                $Options -contains 'WebSelfHost' -and
                ($Options -notcontains 'Manual') -and
                ($Options -notcontains 'Route53') -and
                $Options[-1] -eq 'B. Back'
            }
        }
    }
}
