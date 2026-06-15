BeforeDiscovery {
    # -Skip conditions are evaluated at discovery time, so the availability
    # flags must be computed here, not in BeforeAll.
    $script:poshAcmeAvailable = ($null -ne (Get-Module -ListAvailable -Name 'Posh-ACME'))
    $script:acmeDirectoryConfigured = (-not [string]::IsNullOrEmpty($env:TUACME_PROD_DIRECTORY)) -and
        (-not [string]::IsNullOrEmpty($env:TUACME_STAGING_DIRECTORY))
}

BeforeAll {
    # Integration tier: no stubs, no mocks. Real module import, real file
    # I/O on $TestDrive, and - when Posh-ACME plus a reachable directory are
    # present (TUACME_PROD_DIRECTORY / TUACME_STAGING_DIRECTORY) - the real
    # Posh-ACME store on disk.
    $testsRoot = Split-Path -Parent $PSScriptRoot
    $repoRoot = Split-Path -Parent $testsRoot
    $script:manifestPath = Join-Path (Join-Path $repoRoot 'TU-ACME') 'TU-ACME.psd1'
    $script:fixturesPath = Join-Path $testsRoot 'Fixtures'

    Get-Module -Name 'PoshACME.Stubs', 'WindowsCmdlets.Stubs' | Remove-Module -Force
}

Describe 'TU-ACME module wiring (UC-11.04 / AC-I.4)' -Tag 'Integration' {
    BeforeEach {
        $env:TUACME_DATA_DIR = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        Get-Module -Name 'TU-ACME' | Remove-Module -Force
    }

    AfterAll {
        Get-Module -Name 'TU-ACME' | Remove-Module -Force
    }

    It 'imports for real without errors while unconfigured (AC-A.1)' {
        { Import-Module $script:manifestPath -Force -ErrorAction Stop 3>$null } | Should -Not -Throw
        @(Get-Command -Module 'TU-ACME').Name | Should -Contain 'Start-TUACME'
    }

    It 'persists configuration to disk and reloads it after reimport (AC-A.4, AC-H.1)' {
        Import-Module $script:manifestPath -Force 3>$null
        InModuleScope 'TU-ACME' {
            Save-TUACMEConfig -Config ([pscustomobject]@{
                    ContactEmail        = 'certs@example.com'
                    ProdDirectoryUrl    = 'https://acme.example.com/prod/directory'
                    ProdAccountId       = 'prod-1'
                    StagingDirectoryUrl = 'https://acme.example.com/staging/directory'
                    StagingAccountId    = 'staging-1'
                })
        }

        Get-Module -Name 'TU-ACME' | Remove-Module -Force
        { Import-Module $script:manifestPath -Force -ErrorAction Stop 3>$null } | Should -Not -Throw

        $config = InModuleScope 'TU-ACME' { Get-TUACMEConfig }
        $config.ContactEmail | Should -Be 'certs@example.com'
        $config.ProdAccountId | Should -Be 'prod-1'
        $config.StagingAccountId | Should -Be 'staging-1'
    }

    It 'rejects an on-disk config with missing fields (UC-10.01)' {
        $null = New-Item -ItemType Directory -Path $env:TUACME_DATA_DIR -Force
        Copy-Item -Path (Join-Path $script:fixturesPath 'config.invalid-missing-field.json') -Destination (Join-Path $env:TUACME_DATA_DIR 'config.json')
        Import-Module $script:manifestPath -ArgumentList $true -Force 3>$null

        { InModuleScope 'TU-ACME' { Get-TUACMEConfig } } | Should -Throw '*missing required field*'
    }

    It 'writes config.json as valid JSON readable outside the module' {
        Import-Module $script:manifestPath -ArgumentList $true -Force 3>$null
        InModuleScope 'TU-ACME' {
            Save-TUACMEConfig -Config ([pscustomobject]@{
                    ContactEmail        = 'certs@example.com'
                    ProdDirectoryUrl    = 'https://acme.example.com/prod/directory'
                    ProdAccountId       = 'prod-1'
                    StagingDirectoryUrl = 'https://acme.example.com/staging/directory'
                    StagingAccountId    = 'staging-1'
                })
        }

        $raw = Get-Content -LiteralPath (Join-Path $env:TUACME_DATA_DIR 'config.json') -Raw
        { $raw | ConvertFrom-Json } | Should -Not -Throw
    }
}

Describe 'TU-ACME against the real Posh-ACME store (UC-11.04 / AC-I.4)' -Tag 'Integration' {
    # These need Posh-ACME installed and reachable internal directory URLs in
    # TUACME_PROD_DIRECTORY / TUACME_STAGING_DIRECTORY (the corporate CA or a
    # local Pebble/step-ca). They self-skip elsewhere, e.g. on offline CI.
    BeforeEach {
        $env:TUACME_DATA_DIR = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $env:POSHACME_HOME = Join-Path $TestDrive ('store-{0}' -f [guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $env:POSHACME_HOME -Force
        Get-Module -Name 'TU-ACME' | Remove-Module -Force
        Import-Module $script:manifestPath -ArgumentList $true -Force 3>$null
    }

    AfterEach {
        $env:POSHACME_HOME = $null
    }

    It 'switches the active server through Use-TUACMEProdAccount (AC-B.1)' -Skip:(-not ($script:poshAcmeAvailable -and $script:acmeDirectoryConfigured)) {
        InModuleScope 'TU-ACME' {
            Save-TUACMEConfig -Config ([pscustomobject]@{
                    ContactEmail        = 'certs@example.com'
                    ProdDirectoryUrl    = $env:TUACME_PROD_DIRECTORY
                    ProdAccountId       = ''
                    StagingDirectoryUrl = $env:TUACME_STAGING_DIRECTORY
                    StagingAccountId    = ''
                })
            $null = Use-TUACMEProdAccount
        }

        (Get-PAServer).location | Should -Be $env:TUACME_PROD_DIRECTORY
    }

    It 'switches to staging and back through the dry-run wrapper (AC-B.3, AC-B.4)' -Skip:(-not ($script:poshAcmeAvailable -and $script:acmeDirectoryConfigured)) {
        InModuleScope 'TU-ACME' {
            Save-TUACMEConfig -Config ([pscustomobject]@{
                    ContactEmail        = 'certs@example.com'
                    ProdDirectoryUrl    = $env:TUACME_PROD_DIRECTORY
                    ProdAccountId       = ''
                    StagingDirectoryUrl = $env:TUACME_STAGING_DIRECTORY
                    StagingAccountId    = ''
                })
            $stagingLocation = Invoke-TUACMEDryRun -Operation { (Get-PAServer).location }
            $stagingLocation | Should -Be $env:TUACME_STAGING_DIRECTORY
        }

        (Get-PAServer).location | Should -Be $env:TUACME_PROD_DIRECTORY
    }
}
