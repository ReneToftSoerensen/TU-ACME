#Requires -Modules Pester
Describe 'UC-2.03 — Use-TUACME*Account throws when config not initialized' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc203-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null

        $cfg = [PSCustomObject]@{
            Version = '0.1.0'
            Acme    = [PSCustomObject]@{
                ProdDirectoryUrl    = 'https://acme.corp.local/directory'
                StagingDirectoryUrl = 'https://acme-staging.corp.local/directory'
                ContactEmail        = 'pki@corp.local'
                ProdAccountId       = 'prod-acct-001'
                StagingAccountId    = 'stag-acct-001'
                Initialized         = $false
                InitializedAt       = ''
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

    It 'Use-TUACMEProdAccount throws and does not call Set-PAServer or Set-PAAccount' {
        InModuleScope TU-ACME {
            Mock Set-PAServer  {}
            Mock Set-PAAccount {}

            { Use-TUACMEProdAccount } | Should -Throw '*not initialized*'

            Assert-MockCalled Set-PAServer  -Times 0 -Exactly -Scope It
            Assert-MockCalled Set-PAAccount -Times 0 -Exactly -Scope It
        }
    }

    It 'Use-TUACMEStagingAccount throws and does not call Set-PAServer or Set-PAAccount' {
        InModuleScope TU-ACME {
            Mock Set-PAServer  {}
            Mock Set-PAAccount {}

            { Use-TUACMEStagingAccount } | Should -Throw '*not initialized*'

            Assert-MockCalled Set-PAServer  -Times 0 -Exactly -Scope It
            Assert-MockCalled Set-PAAccount -Times 0 -Exactly -Scope It
        }
    }
}
