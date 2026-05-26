#Requires -Modules Pester
Describe 'UC-6.06 - Plugin menu offers DNS-PERSIST-01 filter' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc606-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'second-tier Show-Menu contains only dns-01-persist plugins when persistent bucket is picked' {
        InModuleScope TU-ACME {
            Mock Invoke-ConsoleClear {}
            Mock Write-Host {}
            Mock Get-PAPlugin -RemoveParameterValidation 'Plugin' -ParameterFilter { -not $Plugin -and -not $Params } -MockWith {
                @(
                    [PSCustomObject]@{ Name = 'Manual';        ChallengeType = 'dns-01' },
                    [PSCustomObject]@{ Name = 'PersistentDns'; ChallengeType = 'dns-01-persist' },
                    [PSCustomObject]@{ Name = 'WebRoot';       ChallengeType = 'http-01' }
                )
            }
            # Tier picker -> DNS-01 (persistent) (index 1). Second tier: -1.
            $script:_uc606_calls = 0
            Mock Show-Menu {
                $i = $script:_uc606_calls
                $script:_uc606_calls = $i + 1
                if ($i -eq 0) { return 1 } else { return -1 }
            }
            Mock Export-Clixml {}
            Mock Invoke-AcmeDnsSetup {}
            Mock Read-Host { return '' }

            Invoke-DnsPluginConfig

            Assert-MockCalled Show-Menu -Times 1 -Scope It -ParameterFilter {
                $Title -match 'persistent' -and
                $Options -contains 'PersistentDns' -and
                ($Options -notcontains 'Manual') -and
                ($Options -notcontains 'WebRoot') -and
                $Options[-1] -eq 'B. Back'
            }
        }
    }
}
