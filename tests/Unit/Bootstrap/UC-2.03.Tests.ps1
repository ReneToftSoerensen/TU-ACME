#Requires -Modules Pester
Describe 'UC-2.03 — Use-TUACME*Account throws when config not initialized' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        # Sandbox config under a temp ProgramData
        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc203-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null

        # Write a non-initialized config
        $cfg = Get-TUACMEConfig
        $cfg.Acme.ProdDirectoryUrl    = 'https://acme.corp.local/directory'
        $cfg.Acme.StagingDirectoryUrl = 'https://acme-staging.corp.local/directory'
        $cfg.Acme.ProdAccountId       = 'prod-acct-001'
        $cfg.Acme.StagingAccountId    = 'stag-acct-001'
        $cfg.Acme.ContactEmail        = 'pki@corp.local'
        $cfg.Acme.Initialized         = $false
        Set-TUACMEConfig -Config $cfg
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'Use-TUACMEProdAccount throws and does not call Set-PAServer or Set-PAAccount' {
        Mock Set-PAServer  -ModuleName TU-ACME {}
        Mock Set-PAAccount -ModuleName TU-ACME {}

        { Use-TUACMEProdAccount } | Should -Throw '*not initialized*'

        Assert-MockCalled Set-PAServer  -ModuleName TU-ACME -Times 0 -Exactly
        Assert-MockCalled Set-PAAccount -ModuleName TU-ACME -Times 0 -Exactly
    }

    It 'Use-TUACMEStagingAccount throws and does not call Set-PAServer or Set-PAAccount' {
        Mock Set-PAServer  -ModuleName TU-ACME {}
        Mock Set-PAAccount -ModuleName TU-ACME {}

        { Use-TUACMEStagingAccount } | Should -Throw '*not initialized*'

        Assert-MockCalled Set-PAServer  -ModuleName TU-ACME -Times 0 -Exactly
        Assert-MockCalled Set-PAAccount -ModuleName TU-ACME -Times 0 -Exactly
    }
}
