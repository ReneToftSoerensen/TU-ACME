BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Invoke-TUACMEOrderCertificate -DryRun (UC-5.02 / AC-D.2, AC-B.3, AC-B.4, AC-J.3)' -Tag 'Unit' {
    BeforeEach {
        # Invoke-TUACMEDryRun is intentionally not mocked: these tests pin the
        # wiring from the order flow through the real staging/restore wrapper.
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
        Mock -ModuleName 'TU-ACME' Use-TUACMEProdAccount { 'https://staging.example/dir' }
        Mock -ModuleName 'TU-ACME' Use-TUACMEStagingAccount { 'https://prod.example/dir' }
        Mock -ModuleName 'TU-ACME' Write-TUACMEEventLog { }
        Mock -ModuleName 'TU-ACME' New-PACertificate {
            [pscustomobject]@{
                Thumbprint = 'STAGING1234567890'
                NotAfter   = (Get-Date).AddDays(90)
            }
        }
    }

    It 'switches to staging before ordering' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMEOrderCertificate -Domain 'www.example.com' -DryRun }

        Should -Invoke -ModuleName 'TU-ACME' Use-TUACMEStagingAccount -Times 1 -Exactly
    }

    It 'orders against the staging account and returns the staging certificate' {
        $result = InModuleScope 'TU-ACME' { Invoke-TUACMEOrderCertificate -Domain 'www.example.com' -DryRun }

        Should -Invoke -ModuleName 'TU-ACME' New-PACertificate -Times 1 -Exactly -ParameterFilter {
            $Domain -contains 'www.example.com'
        }
        $result.Thumbprint | Should -Be 'STAGING1234567890'
    }

    It 'forwards both the FQDN CN and the short hostname SAN through the dry-run wrapper (UC-5.03 / #18)' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMEOrderCertificate -Domain @('df-bpxt4s2-ws.fragt.root.local', 'DF-BPXT4S2-WS') -DryRun }

        Should -Invoke -ModuleName 'TU-ACME' New-PACertificate -Times 1 -Exactly -ParameterFilter {
            $Domain -contains 'df-bpxt4s2-ws.fragt.root.local' -and $Domain -contains 'DF-BPXT4S2-WS'
        }
    }

    It 'restores prod context after the dry-run' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMEOrderCertificate -Domain 'www.example.com' -DryRun }

        Should -Invoke -ModuleName 'TU-ACME' Use-TUACMEProdAccount -Times 1 -Exactly
    }

    It 'restores prod context even when the order fails' {
        Mock -ModuleName 'TU-ACME' New-PACertificate { throw 'staging order exploded' }

        {
            InModuleScope 'TU-ACME' { Invoke-TUACMEOrderCertificate -Domain 'www.example.com' -DryRun }
        } | Should -Throw '*staging order exploded*'

        Should -Invoke -ModuleName 'TU-ACME' Use-TUACMEProdAccount -Times 1 -Exactly
    }

    It 'logs event 1006, not the prod order event 1003' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMEOrderCertificate -Domain 'www.example.com' -DryRun }

        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 1006 -and $EntryType -eq 'Information'
        }
        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 0 -Exactly -ParameterFilter {
            $EventId -eq 1003
        }
    }
}
