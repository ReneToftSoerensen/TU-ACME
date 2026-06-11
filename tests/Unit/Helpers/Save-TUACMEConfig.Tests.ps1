BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Save-TUACMEConfig (UC-10.01)' -Tag 'Unit' {
    BeforeEach {
        $env:TUACME_DATA_DIR = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    }

    It 'creates the data directory and writes valid JSON' {
        InModuleScope 'TU-ACME' {
            $config = [pscustomobject]@{
                ContactEmail        = 'certs@example.com'
                ProdDirectoryUrl    = 'https://acme.example.com/prod/directory'
                ProdAccountId       = 'prod-account-1'
                StagingDirectoryUrl = 'https://acme.example.com/staging/directory'
                StagingAccountId    = 'staging-account-1'
            }
            Save-TUACMEConfig -Config $config
        }

        $path = Join-Path $env:TUACME_DATA_DIR 'config.json'
        Test-Path -LiteralPath $path | Should -BeTrue
        $loaded = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $loaded.ContactEmail | Should -Be 'certs@example.com'
    }

    It 'round-trips through Get-TUACMEConfig' {
        $config = InModuleScope 'TU-ACME' {
            $config = [pscustomobject]@{
                ContactEmail        = 'certs@example.com'
                ProdDirectoryUrl    = 'https://acme.example.com/prod/directory'
                ProdAccountId       = 'prod-account-1'
                StagingDirectoryUrl = 'https://acme.example.com/staging/directory'
                StagingAccountId    = 'staging-account-1'
            }
            Save-TUACMEConfig -Config $config
            Get-TUACMEConfig
        }

        $config.ProdAccountId | Should -Be 'prod-account-1'
        $config.StagingAccountId | Should -Be 'staging-account-1'
    }

    It 'overwrites an existing config' {
        InModuleScope 'TU-ACME' {
            $config = [pscustomobject]@{
                ContactEmail        = 'first@example.com'
                ProdDirectoryUrl    = 'https://acme.example.com/prod/directory'
                ProdAccountId       = ''
                StagingDirectoryUrl = 'https://acme.example.com/staging/directory'
                StagingAccountId    = ''
            }
            Save-TUACMEConfig -Config $config
            $config.ContactEmail = 'second@example.com'
            Save-TUACMEConfig -Config $config
        }

        $path = Join-Path $env:TUACME_DATA_DIR 'config.json'
        (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json).ContactEmail |
            Should -Be 'second@example.com'
    }
}
