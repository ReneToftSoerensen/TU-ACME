BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
    $testsRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:fixturesPath = Join-Path $testsRoot 'Fixtures'
}

Describe 'Get-TUACMEConfig (UC-10.01 / AC-H.1)' -Tag 'Unit' {
    It 'loads a valid config with all required fields' {
        $path = Join-Path $fixturesPath 'config.valid.json'

        $config = InModuleScope 'TU-ACME' -Parameters @{ Path = $path } {
            param($Path)
            Get-TUACMEConfig -Path $Path
        }

        $config.ContactEmail | Should -Be 'certs@example.com'
        $config.ProdDirectoryUrl | Should -Be 'https://acme.example.com/prod/directory'
        $config.ProdAccountId | Should -Be 'prod-account-1'
        $config.StagingDirectoryUrl | Should -Be 'https://acme.example.com/staging/directory'
        $config.StagingAccountId | Should -Be 'staging-account-1'
    }

    It 'throws a descriptive error when the file is missing' {
        $path = Join-Path $TestDrive 'missing-config.json'

        {
            InModuleScope 'TU-ACME' -Parameters @{ Path = $path } {
                param($Path)
                Get-TUACMEConfig -Path $Path
            }
        } | Should -Throw '*not found*'
    }

    It 'throws a validation error naming the missing field' {
        $path = Join-Path $fixturesPath 'config.invalid-missing-field.json'

        {
            InModuleScope 'TU-ACME' -Parameters @{ Path = $path } {
                param($Path)
                Get-TUACMEConfig -Path $Path
            }
        } | Should -Throw '*StagingDirectoryUrl*'
    }

    It 'throws when the file is not valid JSON' {
        $path = Join-Path $TestDrive 'broken.json'
        Set-Content -Path $path -Value 'not json {'

        {
            InModuleScope 'TU-ACME' -Parameters @{ Path = $path } {
                param($Path)
                Get-TUACMEConfig -Path $Path
            }
        } | Should -Throw '*not valid JSON*'
    }

    Context 'with empty account ids' {
        BeforeEach {
            $script:partialPath = Join-Path $TestDrive 'partial-config.json'
            Set-Content -Path $partialPath -Value (@'
{
  "ContactEmail": "certs@example.com",
  "ProdDirectoryUrl": "https://acme.example.com/prod/directory",
  "ProdAccountId": "",
  "StagingDirectoryUrl": "https://acme.example.com/staging/directory",
  "StagingAccountId": ""
}
'@)
        }

        It 'rejects them by default' {
            {
                InModuleScope 'TU-ACME' -Parameters @{ Path = $partialPath } {
                    param($Path)
                    Get-TUACMEConfig -Path $Path
                }
            } | Should -Throw '*ProdAccountId*'
        }

        It 'allows them when account ids are not required' {
            $config = InModuleScope 'TU-ACME' -Parameters @{ Path = $partialPath } {
                param($Path)
                Get-TUACMEConfig -Path $Path -RequireAccountIds $false
            }

            $config.ContactEmail | Should -Be 'certs@example.com'
        }
    }
}
