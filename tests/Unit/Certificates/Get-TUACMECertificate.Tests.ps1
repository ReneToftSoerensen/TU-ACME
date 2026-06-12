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
}
