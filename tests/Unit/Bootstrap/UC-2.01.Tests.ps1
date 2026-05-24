#Requires -Modules Pester
Describe 'UC-2.01 — Use-TUACMEProdAccount switches server and account' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        # Sandbox config under a temp ProgramData
        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc201-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null

        # Write a fully-initialized config
        $cfg = Get-TUACMEConfig
        $cfg.Acme.ProdDirectoryUrl    = 'https://acme.corp.local/directory'
        $cfg.Acme.StagingDirectoryUrl = 'https://acme-staging.corp.local/directory'
        $cfg.Acme.ProdAccountId       = 'prod-acct-001'
        $cfg.Acme.StagingAccountId    = 'stag-acct-001'
        $cfg.Acme.ContactEmail        = 'pki@corp.local'
        $cfg.Acme.Initialized         = $true
        Set-TUACMEConfig -Config $cfg
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'calls Set-PAServer with prod URL then Set-PAAccount with prod ID' {
        Mock Set-PAServer  -ModuleName TU-ACME {}
        Mock Set-PAAccount -ModuleName TU-ACME {}

        Use-TUACMEProdAccount

        Assert-MockCalled Set-PAServer  -ModuleName TU-ACME -ParameterFilter { $DirectoryUrl -eq 'https://acme.corp.local/directory' } -Times 1 -Exactly
        Assert-MockCalled Set-PAAccount -ModuleName TU-ACME -ParameterFilter { $ID -eq 'prod-acct-001' } -Times 1 -Exactly
    }
}
