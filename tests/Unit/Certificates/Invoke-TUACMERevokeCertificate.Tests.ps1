BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Invoke-TUACMERevokeCertificate (UC-6.02 / AC-D.4)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Use-TUACMEProdAccount { 'https://previous.example/dir' }
        Mock -ModuleName 'TU-ACME' Write-TUACMEEventLog { }
        Mock -ModuleName 'TU-ACME' Get-PACertificate {
            [pscustomobject]@{ Thumbprint = 'REVOKE1234'; MainDomain = 'www.example.com' }
        }
        Mock -ModuleName 'TU-ACME' Revoke-PACertificate { }
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISBinding { @() }
    }

    It 'ensures prod context before revoking' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMERevokeCertificate -Domain 'www.example.com' }

        Should -Invoke -ModuleName 'TU-ACME' Use-TUACMEProdAccount -Times 1 -Exactly
    }

    It 'revokes via Revoke-PACertificate for the selected domain' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMERevokeCertificate -Domain 'www.example.com' }

        Should -Invoke -ModuleName 'TU-ACME' Revoke-PACertificate -Times 1 -Exactly -ParameterFilter {
            $MainDomain -eq 'www.example.com'
        }
    }

    It 'logs event 1004 with the domain and thumbprint' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMERevokeCertificate -Domain 'www.example.com' }

        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 1004 -and $EntryType -eq 'Information' -and
            $Message -like '*www.example.com*' -and $Message -like '*REVOKE1234*'
        }
    }

    It 'reports IIS bindings still serving the revoked cert' {
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISBinding {
            @([pscustomobject]@{ SiteName = 'S'; Thumbprint = 'REVOKE1234'; Protocol = 'https' })
        }

        $result = InModuleScope 'TU-ACME' { Invoke-TUACMERevokeCertificate -Domain 'www.example.com' }

        @($result.AffectedBindings).Count | Should -Be 1
        $result.Thumbprint | Should -Be 'REVOKE1234'
    }

    It 'logs event 3004 and rethrows when revocation fails' {
        Mock -ModuleName 'TU-ACME' Revoke-PACertificate { throw 'revoke exploded' }

        {
            InModuleScope 'TU-ACME' { Invoke-TUACMERevokeCertificate -Domain 'www.example.com' }
        } | Should -Throw '*revoke exploded*'

        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 3004 -and $EntryType -eq 'Error'
        }
    }
}
