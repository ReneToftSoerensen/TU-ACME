#Requires -Modules Pester
Describe 'UC-6.03 - DNS plugin save calls Set-PAPluginArgs' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc603-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'persists the hashtable with Set-PAPluginArgs on y confirmation' {
        InModuleScope TU-ACME {
            Mock Invoke-ConsoleClear {}
            Mock Write-Host {}
            Mock Get-PAPlugin -RemoveParameterValidation 'Plugin' -ParameterFilter { -not $Plugin -and -not $Params } -MockWith {
                @( [PSCustomObject]@{ Name = 'Foo'; ChallengeType = 'dns-01' } )
            }
            Mock Get-PAPlugin -RemoveParameterValidation 'Plugin' -ParameterFilter { $Plugin -eq 'Foo' -and $Params } -MockWith {
                @( [PSCustomObject]@{ Name = 'ServerName'; Mandatory = $true } )
            }
            # Tier picker -> DNS-01 (0); plugin picker -> Foo (0).
            Mock Show-Menu { return 0 }
            Mock Export-Clixml {}
            Mock Invoke-AcmeDnsSetup {}

            $script:_ans = @('host.example', 'y', '')
            $script:_idx = 0
            Mock Read-Host {
                $i = $script:_idx
                $script:_idx = $i + 1
                if ($i -ge $script:_ans.Count) { return '' }
                return $script:_ans[$i]
            }

            Invoke-DnsPluginConfig

            Assert-MockCalled Export-Clixml -Times 1 -Scope It -ParameterFilter {
                $Path -like '*plugin-args-Foo.xml' -and
                $InputObject -is [hashtable] -and
                $InputObject['ServerName'] -eq 'host.example'
            }
        }
    }

    It 'does NOT call Set-PAPluginArgs when the operator declines' {
        InModuleScope TU-ACME {
            Mock Invoke-ConsoleClear {}
            Mock Write-Host {}
            Mock Get-PAPlugin -RemoveParameterValidation 'Plugin' -ParameterFilter { -not $Plugin -and -not $Params } -MockWith {
                @( [PSCustomObject]@{ Name = 'Foo'; ChallengeType = 'dns-01' } )
            }
            Mock Get-PAPlugin -RemoveParameterValidation 'Plugin' -ParameterFilter { $Plugin -eq 'Foo' -and $Params } -MockWith {
                @( [PSCustomObject]@{ Name = 'ServerName'; Mandatory = $true } )
            }
            Mock Show-Menu { return 0 }
            Mock Export-Clixml {}
            Mock Invoke-AcmeDnsSetup {}

            $script:_ans2 = @('host.example', 'n', '')
            $script:_idx2 = 0
            Mock Read-Host {
                $i = $script:_idx2
                $script:_idx2 = $i + 1
                if ($i -ge $script:_ans2.Count) { return '' }
                return $script:_ans2[$i]
            }

            Invoke-DnsPluginConfig

            Assert-MockCalled Export-Clixml -Times 0 -Scope It -Exactly
        }
    }
}
