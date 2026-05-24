#Requires -Modules Pester
Describe 'UC-6.02 - DNS plugin prompts mask secret-named parameters' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc602-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'masks parameters whose names match key|password|token|secret' {
        InModuleScope TU-ACME {
            Mock Invoke-ConsoleClear {}
            Mock Write-Host {}
            Mock Get-PAPlugin -RemoveParameterValidation 'Plugin' -ParameterFilter { -not $Plugin -and -not $Params } -MockWith {
                @( [PSCustomObject]@{ Name = 'Foo' } )
            }
            Mock Get-PAPlugin -RemoveParameterValidation 'Plugin' -ParameterFilter { $Plugin -eq 'Foo' -and $Params } -MockWith {
                @(
                    [PSCustomObject]@{ Name = 'ApiKey';     Mandatory = $true },
                    [PSCustomObject]@{ Name = 'Token';      Mandatory = $true },
                    [PSCustomObject]@{ Name = 'ServerName'; Mandatory = $true }
                )
            }
            # Pick index 0 (Foo)
            Mock Show-Menu { return 0 }
            Mock Export-Clixml {}
            Mock Invoke-AcmeDnsSetup {}

            # Secret prompts return a secure string; plain prompt returns 'host'; confirm returns 'n' to skip save.
            Mock Read-Host -ParameterFilter { $AsSecureString } -MockWith {
                ConvertTo-SecureString -String 'secret-val' -AsPlainText -Force
            }
            Mock Read-Host -ParameterFilter { -not $AsSecureString } -MockWith { 'host.example' }

            Invoke-DnsPluginConfig

            # Secret-named params went through -AsSecureString (ApiKey + Token = 2 calls)
            Assert-MockCalled Read-Host -Times 2 -Scope It -ParameterFilter { $AsSecureString }
            # ServerName + save confirmation + "Press Enter to continue" go through plain Read-Host
            Assert-MockCalled Read-Host -Times 1 -Scope It -ParameterFilter {
                -not $AsSecureString -and $Prompt -match 'ServerName'
            }
            # Sanity: AsSecureString was never used for ServerName
            Assert-MockCalled Read-Host -Times 0 -Scope It -ParameterFilter {
                $AsSecureString -and $Prompt -match 'ServerName'
            }
        }
    }
}
