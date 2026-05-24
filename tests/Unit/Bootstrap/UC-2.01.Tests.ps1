#Requires -Modules Pester
Describe 'UC-2.01 — Use-TUACMEProdAccount switches server and account' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc201-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null

        $cfg = [PSCustomObject]@{
            Version = '0.1.0'
            Acme    = [PSCustomObject]@{
                ProdDirectoryUrl    = 'https://acme.corp.local/directory'
                StagingDirectoryUrl = 'https://acme-staging.corp.local/directory'
                ContactEmail        = 'pki@corp.local'
                ProdAccountId       = 'prod-acct-001'
                StagingAccountId    = 'stag-acct-001'
                Initialized         = $true
                InitializedAt       = '2026-05-24T00:00:00Z'
            }
        }
        $configPath = Join-Path $env:ProgramData 'TU-ACME\config.json'
        $cfg | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath -Encoding UTF8
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'calls Set-PAServer with prod URL then Set-PAAccount with prod ID' {
        InModuleScope TU-ACME {
            Mock Set-PAServer  {}
            Mock Set-PAAccount {}

            Use-TUACMEProdAccount

            Assert-MockCalled Set-PAServer  -ParameterFilter { $DirectoryUrl -eq 'https://acme.corp.local/directory' } -Times 1 -Exactly -Scope It
            Assert-MockCalled Set-PAAccount -ParameterFilter { $ID -eq 'prod-acct-001' } -Times 1 -Exactly -Scope It
        }
    }
}
