#Requires -Modules Pester
Describe 'Get-TUACMEConfig backfills defaults onto partial config.json' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
    }
    AfterAll {
        if ($env:ProgramData -ne $script:OriginalProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        # Fresh sandbox per test so we can write different config.json shapes.
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-cfgmerge-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
    }
    AfterEach {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'adds missing Acme.* properties to a half-written config' {
        # Simulate a config.json left behind by a half-completed first-run.
        # The Acme block exists but only contains Initialized=$false; every
        # other field is absent.
        $partial = @{
            Version = '0.2.0'
            Acme    = @{ Initialized = $false }
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $env:ProgramData 'TU-ACME\config.json') -Value $partial -Encoding UTF8

        InModuleScope TU-ACME {
            $cfg = Get-TUACMEConfig
            $cfg.Acme.PSObject.Properties.Match('ProdDirectoryUrl').Count    | Should -Be 1
            $cfg.Acme.PSObject.Properties.Match('StagingDirectoryUrl').Count | Should -Be 1
            $cfg.Acme.PSObject.Properties.Match('ContactEmail').Count        | Should -Be 1
            $cfg.Acme.PSObject.Properties.Match('ProdAccountId').Count       | Should -Be 1
            $cfg.Acme.PSObject.Properties.Match('StagingAccountId').Count    | Should -Be 1
            $cfg.Acme.PSObject.Properties.Match('InitializedAt').Count       | Should -Be 1
            $cfg.Acme.Initialized | Should -BeFalse   # preserved from loaded JSON
        }
    }

    It 'preserves loaded values when they are present' {
        $full = @{
            Acme = @{
                ProdDirectoryUrl    = 'https://prod.example/dir'
                StagingDirectoryUrl = 'https://staging.example/dir'
                ContactEmail        = 'ops@example.com'
                ProdAccountId       = 'p1'
                StagingAccountId    = 's1'
                Initialized         = $true
                InitializedAt       = '2026-05-24T00:00:00Z'
            }
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $env:ProgramData 'TU-ACME\config.json') -Value $full -Encoding UTF8

        InModuleScope TU-ACME {
            $cfg = Get-TUACMEConfig
            $cfg.Acme.ProdDirectoryUrl    | Should -Be 'https://prod.example/dir'
            $cfg.Acme.StagingDirectoryUrl | Should -Be 'https://staging.example/dir'
            $cfg.Acme.ContactEmail        | Should -Be 'ops@example.com'
            $cfg.Acme.Initialized         | Should -BeTrue
        }
    }

    It 'adds missing top-level blocks when the config is bare-minimum' {
        # Edge case: a config.json with just Version, no Acme/Email/etc.
        $bare = @{ Version = '0.2.0' } | ConvertTo-Json
        Set-Content -Path (Join-Path $env:ProgramData 'TU-ACME\config.json') -Value $bare -Encoding UTF8

        InModuleScope TU-ACME {
            $cfg = Get-TUACMEConfig
            $cfg.Acme          | Should -Not -BeNullOrEmpty
            $cfg.ScheduledTask | Should -Not -BeNullOrEmpty
            $cfg.Email         | Should -Not -BeNullOrEmpty
            $cfg.Dashboard     | Should -Not -BeNullOrEmpty
            $cfg.DNS           | Should -Not -BeNullOrEmpty
            $cfg.Acme.Initialized | Should -BeFalse
        }
    }
}
