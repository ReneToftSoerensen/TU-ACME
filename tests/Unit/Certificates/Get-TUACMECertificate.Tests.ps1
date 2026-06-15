BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Get-TUACMECertificate (UC-12.01)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Use-TUACMEProdAccount { 'https://previous.example/dir' }
        Mock -ModuleName 'TU-ACME' Get-PACertificate {
            @(
                [pscustomobject]@{ MainDomain = 'a.example.com'; Thumbprint = 'AAA' },
                [pscustomobject]@{ MainDomain = 'b.example.com'; Thumbprint = 'BBB' }
            )
        }
    }

    It 'ensures prod context before reading the store' {
        $null = InModuleScope 'TU-ACME' { Get-TUACMECertificate }

        Should -Invoke -ModuleName 'TU-ACME' Use-TUACMEProdAccount -Times 1 -Exactly
    }

    It 'lists all certificates via Get-PACertificate -List' {
        $result = @(InModuleScope 'TU-ACME' { Get-TUACMECertificate })

        Should -Invoke -ModuleName 'TU-ACME' Get-PACertificate -Times 1 -Exactly -ParameterFilter {
            $List -eq $true
        }
        $result.Count | Should -Be 2
    }

    It 'returns an empty array when the store is empty' {
        Mock -ModuleName 'TU-ACME' Get-PACertificate { @() }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMECertificate })

        $result.Count | Should -Be 0
    }

    It 'filters out phantom entries from abandoned or pending orders' {
        # Get-PACertificate -List surfaces all-null entries for orders that
        # never completed; they must not reach the dashboard or the sweep.
        Mock -ModuleName 'TU-ACME' Get-PACertificate {
            @(
                [pscustomobject]@{ MainDomain = $null; Thumbprint = $null; NotAfter = $null; CertFile = $null },
                [pscustomobject]@{ MainDomain = 'real.example.com'; Thumbprint = 'AAA'; NotAfter = (Get-Date).AddDays(30); CertFile = $null }
            )
        }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMECertificate })

        $result.Count | Should -Be 1
        $result[0].MainDomain | Should -Be 'real.example.com'
    }

    It 'keeps an issued cert with empty MainDomain and backfills it from the subject CN' {
        # Internal CAs can issue successfully while leaving MainDomain empty
        # in the Posh-ACME order.
        $certFile = Join-Path $TestDrive 'cert.cer'
        Set-Content -Path $certFile -Value 'fake cert bytes'
        Mock -ModuleName 'TU-ACME' Get-PACertificate {
            @([pscustomobject]@{ MainDomain = ''; Thumbprint = 'BBB'; NotAfter = (Get-Date).AddDays(30); CertFile = $certFile })
        }
        Mock -ModuleName 'TU-ACME' Get-TUACMECertificateSubjectCN { 'cn.example.com' }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMECertificate })

        $result.Count | Should -Be 1
        $result[0].MainDomain | Should -Be 'cn.example.com'
    }

    It 'falls back to the cert folder name when the subject CN is unreadable' {
        $certDir = Join-Path $TestDrive 'folder.example.com'
        $null = New-Item -ItemType Directory -Path $certDir -Force
        $certFile = Join-Path $certDir 'cert.cer'
        Set-Content -Path $certFile -Value 'fake cert bytes'
        Mock -ModuleName 'TU-ACME' Get-PACertificate {
            @([pscustomobject]@{ MainDomain = ''; Thumbprint = 'CCC'; NotAfter = (Get-Date).AddDays(30); CertFile = $certFile })
        }
        Mock -ModuleName 'TU-ACME' Get-TUACMECertificateSubjectCN { '' }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMECertificate })

        $result[0].MainDomain | Should -Be 'folder.example.com'
    }
}
