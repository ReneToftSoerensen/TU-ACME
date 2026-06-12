BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Use-TUACMEStagingAccount (UC-2.01 / AC-B.2)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Get-TUACMEConfig {
            [pscustomobject]@{
                ContactEmail        = 'certs@example.com'
                ProdDirectoryUrl    = 'https://acme.example.com/prod/directory'
                ProdAccountId       = 'prod-account-1'
                StagingDirectoryUrl = 'https://acme.example.com/staging/directory'
                StagingAccountId    = 'staging-account-1'
            }
        }
        Mock -ModuleName 'TU-ACME' Get-PAServer {
            [pscustomobject]@{ location = 'https://previous.example/dir' }
        }
        Mock -ModuleName 'TU-ACME' Set-PAServer { }
        Mock -ModuleName 'TU-ACME' Set-PAAccount { }
    }

    It 'sets the active server to the staging directory URL' {
        $null = InModuleScope 'TU-ACME' { Use-TUACMEStagingAccount }

        Should -Invoke -ModuleName 'TU-ACME' Set-PAServer -Times 1 -Exactly -ParameterFilter {
            $DirectoryUrl -eq 'https://acme.example.com/staging/directory'
        }
    }

    It 'sets the active account to the staging account id' {
        $null = InModuleScope 'TU-ACME' { Use-TUACMEStagingAccount }

        Should -Invoke -ModuleName 'TU-ACME' Set-PAAccount -Times 1 -Exactly -ParameterFilter {
            $ID -eq 'staging-account-1'
        }
    }

    It 'returns the previously active server URL' {
        $result = InModuleScope 'TU-ACME' { Use-TUACMEStagingAccount }

        $result | Should -Be 'https://previous.example/dir'
    }

    It 'returns null when no server was active' {
        Mock -ModuleName 'TU-ACME' Get-PAServer { $null }

        $result = InModuleScope 'TU-ACME' { Use-TUACMEStagingAccount }

        $result | Should -BeNullOrEmpty
    }

    It 'skips Set-PAAccount while the account id is still empty' {
        Mock -ModuleName 'TU-ACME' Get-TUACMEConfig {
            [pscustomobject]@{
                ContactEmail        = 'certs@example.com'
                ProdDirectoryUrl    = 'https://acme.example.com/prod/directory'
                ProdAccountId       = ''
                StagingDirectoryUrl = 'https://acme.example.com/staging/directory'
                StagingAccountId    = ''
            }
        }

        $null = InModuleScope 'TU-ACME' { Use-TUACMEStagingAccount }

        Should -Invoke -ModuleName 'TU-ACME' Set-PAServer -Times 1 -Exactly
        Should -Invoke -ModuleName 'TU-ACME' Set-PAAccount -Times 0 -Exactly
    }
}
