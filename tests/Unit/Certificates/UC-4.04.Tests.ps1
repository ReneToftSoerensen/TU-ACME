#Requires -Modules Pester
Describe 'UC-4.04 — Dry-run cancels on Esc and restores prod' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force
        . "$PSScriptRoot\..\..\Fixtures\FakeObjects.ps1"

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc404-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null

        $cfg = [PSCustomObject]@{
            Version = '0.3.0'
            Acme    = [PSCustomObject]@{
                ProdDirectoryUrl    = 'https://prod.example/dir'
                StagingDirectoryUrl = 'https://staging.example/dir'
                ProdAccountId       = 'prod1'
                StagingAccountId    = 'stag1'
                ContactEmail        = 'ops@example.com'
                Initialized         = $true
                InitializedAt       = '2026-05-24T00:00:00Z'
            }
        }
        $cfg | ConvertTo-Json -Depth 5 |
            Set-Content -Path (Join-Path $env:ProgramData 'TU-ACME\config.json') -Encoding UTF8
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'cancels at the domain prompt; New-PACertificate not called; prod restored' {
        InModuleScope TU-ACME {
            Mock Use-TUACMEStagingAccount {}
            Mock Use-TUACMEProdAccount    {}
            Mock Get-PAPluginArgs         { @{ ApiKey = 'dummy' } }
            Mock New-PACertificate        {}
            Mock Set-PAOrder              {}
            Mock Write-EventLogEntry      {}
            Mock Show-Spinner             { param($Message, $ScriptBlock) & $ScriptBlock }
            Mock Invoke-ConsoleClear      {}
            Mock Read-LineOrEscape        { $null }

            Invoke-DryRunOrder

            Assert-MockCalled New-PACertificate    -Times 0 -Scope It
            Assert-MockCalled Write-EventLogEntry  -Times 0 -Scope It -ParameterFilter { $EventId -eq 1006 }
            Assert-MockCalled Use-TUACMEProdAccount -Times 1 -Scope It
        }
    }

    It 'cancels at the SANs prompt and still restores prod' {
        InModuleScope TU-ACME {
            Mock Use-TUACMEStagingAccount {}
            Mock Use-TUACMEProdAccount    {}
            Mock Get-PAPluginArgs         { @{ ApiKey = 'dummy' } }
            Mock New-PACertificate        {}
            Mock Set-PAOrder              {}
            Mock Write-EventLogEntry      {}
            Mock Show-Spinner             { param($Message, $ScriptBlock) & $ScriptBlock }
            Mock Invoke-ConsoleClear      {}

            $script:_uc404ans = @('example.com', $null)
            $script:_uc404idx = 0
            Mock Read-LineOrEscape {
                $v = $script:_uc404ans[$script:_uc404idx]
                $script:_uc404idx = $script:_uc404idx + 1
                return $v
            }

            Invoke-DryRunOrder

            Assert-MockCalled New-PACertificate     -Times 0 -Scope It
            Assert-MockCalled Use-TUACMEProdAccount -Times 1 -Scope It
        }
    }

    It 'cancels at the plugin prompt and still restores prod' {
        InModuleScope TU-ACME {
            Mock Use-TUACMEStagingAccount {}
            Mock Use-TUACMEProdAccount    {}
            Mock Get-PAPluginArgs         { @{ ApiKey = 'dummy' } }
            Mock New-PACertificate        {}
            Mock Set-PAOrder              {}
            Mock Write-EventLogEntry      {}
            Mock Show-Spinner             { param($Message, $ScriptBlock) & $ScriptBlock }
            Mock Invoke-ConsoleClear      {}

            $script:_uc404ans = @('example.com', '', $null)
            $script:_uc404idx = 0
            Mock Read-LineOrEscape {
                $v = $script:_uc404ans[$script:_uc404idx]
                $script:_uc404idx = $script:_uc404idx + 1
                return $v
            }

            Invoke-DryRunOrder

            Assert-MockCalled New-PACertificate     -Times 0 -Scope It
            Assert-MockCalled Use-TUACMEProdAccount -Times 1 -Scope It
        }
    }

    It 'cancels at the confirmation prompt and still restores prod' {
        InModuleScope TU-ACME {
            Mock Use-TUACMEStagingAccount {}
            Mock Use-TUACMEProdAccount    {}
            Mock Get-PAPluginArgs         { @{ ApiKey = 'dummy' } }
            Mock New-PACertificate        {}
            Mock Set-PAOrder              {}
            Mock Write-EventLogEntry      {}
            Mock Show-Spinner             { param($Message, $ScriptBlock) & $ScriptBlock }
            Mock Invoke-ConsoleClear      {}

            $script:_uc404ans = @('example.com', '', 'Manual', $null)
            $script:_uc404idx = 0
            Mock Read-LineOrEscape {
                $v = $script:_uc404ans[$script:_uc404idx]
                $script:_uc404idx = $script:_uc404idx + 1
                return $v
            }

            Invoke-DryRunOrder

            Assert-MockCalled New-PACertificate     -Times 0 -Scope It
            Assert-MockCalled Use-TUACMEProdAccount -Times 1 -Scope It
        }
    }
}
