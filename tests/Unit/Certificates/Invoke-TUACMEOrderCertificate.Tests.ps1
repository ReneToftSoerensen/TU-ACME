BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Invoke-TUACMEOrderCertificate (UC-5.01 / AC-D.1, AC-J.2)' -Tag 'Unit' {
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
        Mock -ModuleName 'TU-ACME' Get-TUACMEDNSConfig { $null }
        Mock -ModuleName 'TU-ACME' Use-TUACMEProdAccount { 'https://previous.example/dir' }
        Mock -ModuleName 'TU-ACME' Use-TUACMEStagingAccount { 'https://prod.example/dir' }
        Mock -ModuleName 'TU-ACME' Write-TUACMEEventLog { }
        Mock -ModuleName 'TU-ACME' New-PACertificate {
            [pscustomobject]@{
                Thumbprint = 'ABCDEF1234567890'
                NotAfter   = (Get-Date).AddDays(90)
            }
        }
    }

    It 'ensures prod context before ordering' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMEOrderCertificate -Domain 'www.example.com' }

        Should -Invoke -ModuleName 'TU-ACME' Use-TUACMEProdAccount -Times 1 -Exactly
        Should -Invoke -ModuleName 'TU-ACME' Use-TUACMEStagingAccount -Times 0 -Exactly
    }

    It 'orders via New-PACertificate with the domain and configured contact email' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMEOrderCertificate -Domain 'www.example.com' }

        Should -Invoke -ModuleName 'TU-ACME' New-PACertificate -Times 1 -Exactly -ParameterFilter {
            $Domain -contains 'www.example.com' -and $Contact -contains 'certs@example.com'
        }
    }

    It 'returns the certificate thumbprint and expiry' {
        $result = InModuleScope 'TU-ACME' { Invoke-TUACMEOrderCertificate -Domain 'www.example.com' }

        $result.Domain | Should -Be 'www.example.com'
        $result.Thumbprint | Should -Be 'ABCDEF1234567890'
        $result.NotAfter | Should -BeOfType [datetime]
    }

    It 'logs event 1003 with domain and thumbprint on success' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMEOrderCertificate -Domain 'www.example.com' }

        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 1003 -and
            $EntryType -eq 'Information' -and
            $Message -like '*www.example.com*' -and
            $Message -like '*ABCDEF1234567890*'
        }
    }

    It 'logs event 3002 and rethrows when the order fails' {
        Mock -ModuleName 'TU-ACME' New-PACertificate { throw 'CA unreachable' }

        {
            InModuleScope 'TU-ACME' { Invoke-TUACMEOrderCertificate -Domain 'www.example.com' }
        } | Should -Throw '*CA unreachable*'

        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 3002 -and $EntryType -eq 'Error' -and $Message -like '*www.example.com*'
        }
        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 0 -Exactly -ParameterFilter {
            $EventId -eq 1003
        }
    }

    It 'passes the configured DNS plugin and decrypted args to New-PACertificate (UC-10.03)' {
        Mock -ModuleName 'TU-ACME' Get-TUACMEDNSConfig {
            [pscustomobject]@{
                PluginName = 'Cloudflare'
                PluginArgs = @{ CFToken = (New-Object System.Security.SecureString) }
            }
        }

        $null = InModuleScope 'TU-ACME' { Invoke-TUACMEOrderCertificate -Domain 'www.example.com' }

        Should -Invoke -ModuleName 'TU-ACME' New-PACertificate -Times 1 -Exactly -ParameterFilter {
            $Plugin -eq 'Cloudflare' -and $PluginArgs.ContainsKey('CFToken')
        }
    }
}
