BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Import-TUACMECertificate (UC-6.01, UC-7.02 / AC-E.3)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $true }
        Mock -ModuleName 'TU-ACME' Write-TUACMEEventLog { }
        Mock -ModuleName 'TU-ACME' Import-PfxCertificate {
            [pscustomobject]@{ Thumbprint = 'IMPORTED1234' }
        }

        $script:pfxPath = Join-Path $TestDrive 'fullchain.pfx'
        Set-Content -Path $script:pfxPath -Value 'fake pfx bytes'
    }

    It 'throws on non-Windows platforms' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $false }

        {
            InModuleScope 'TU-ACME' {
                Import-TUACMECertificate -Certificate ([pscustomobject]@{ PfxFullChain = 'x'; MainDomain = 'www.example.com' })
            }
        } | Should -Throw '*requires Windows*'
    }

    It 'throws when the PFX file does not exist' {
        {
            InModuleScope 'TU-ACME' {
                Import-TUACMECertificate -Certificate ([pscustomobject]@{ PfxFullChain = 'C:\does\not\exist.pfx'; MainDomain = 'www.example.com' })
            }
        } | Should -Throw '*PFX not found*'
    }

    It 'imports the PFX into LocalMachine\My and returns the thumbprint' {
        $result = InModuleScope 'TU-ACME' -Parameters @{ PfxPath = $script:pfxPath } {
            param($PfxPath)
            Import-TUACMECertificate -Certificate ([pscustomobject]@{
                    PfxFullChain = $PfxPath
                    PfxPass      = (New-Object System.Security.SecureString)
                    MainDomain   = 'www.example.com'
                })
        }

        Should -Invoke -ModuleName 'TU-ACME' Import-PfxCertificate -Times 1 -Exactly -ParameterFilter {
            $CertStoreLocation -eq 'Cert:\LocalMachine\My' -and $null -ne $Password
        }
        $result | Should -Be 'IMPORTED1234'
    }

    It 'returns the leaf thumbprint when a full-chain PFX imports multiple certs' {
        Mock -ModuleName 'TU-ACME' Import-PfxCertificate {
            @(
                [pscustomobject]@{ Thumbprint = 'ROOT0000'; HasPrivateKey = $false },
                [pscustomobject]@{ Thumbprint = 'LEAF1111'; HasPrivateKey = $true }
            )
        }

        $result = InModuleScope 'TU-ACME' -Parameters @{ PfxPath = $script:pfxPath } {
            param($PfxPath)
            Import-TUACMECertificate -Certificate ([pscustomobject]@{
                    PfxFullChain = $PfxPath
                    MainDomain   = 'www.example.com'
                })
        }

        $result | Should -Be 'LEAF1111'
    }

    It 'logs event 1011 on successful import' {
        $null = InModuleScope 'TU-ACME' -Parameters @{ PfxPath = $script:pfxPath } {
            param($PfxPath)
            Import-TUACMECertificate -Certificate ([pscustomobject]@{
                    PfxFullChain = $PfxPath
                    MainDomain   = 'www.example.com'
                })
        }

        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 1011 -and $EntryType -eq 'Information' -and $Message -like '*www.example.com*'
        }
    }
}
