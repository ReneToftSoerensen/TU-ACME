BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Invoke-TUACMERenewCertificate (UC-6.01 / AC-D.3)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Use-TUACMEProdAccount { 'https://previous.example/dir' }
        Mock -ModuleName 'TU-ACME' Write-TUACMEEventLog { }
        Mock -ModuleName 'TU-ACME' Get-PACertificate {
            [pscustomobject]@{ Thumbprint = 'OLD1234'; MainDomain = 'www.example.com' }
        }
        Mock -ModuleName 'TU-ACME' Submit-Renewal {
            [pscustomobject]@{
                Thumbprint   = 'NEW5678'
                MainDomain   = 'www.example.com'
                PfxFullChain = 'C:\store\fullchain.pfx'
                NotAfter     = (Get-Date).AddDays(90)
            }
        }
        Mock -ModuleName 'TU-ACME' Import-TUACMECertificate { 'NEW5678' }
    }

    It 'ensures prod context before renewing' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMERenewCertificate -Domain 'www.example.com' }

        Should -Invoke -ModuleName 'TU-ACME' Use-TUACMEProdAccount -Times 1 -Exactly
    }

    It 'renews via Submit-Renewal for the selected domain' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMERenewCertificate -Domain 'www.example.com' }

        Should -Invoke -ModuleName 'TU-ACME' Submit-Renewal -Times 1 -Exactly -ParameterFilter {
            $MainDomain -eq 'www.example.com' -and $Force -eq $true
        }
    }

    It 'imports the renewed certificate to LocalMachine\My' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMERenewCertificate -Domain 'www.example.com' }

        Should -Invoke -ModuleName 'TU-ACME' Import-TUACMECertificate -Times 1 -Exactly -ParameterFilter {
            $Certificate.Thumbprint -eq 'NEW5678'
        }
    }

    It 'returns the old and new thumbprints' {
        $result = InModuleScope 'TU-ACME' { Invoke-TUACMERenewCertificate -Domain 'www.example.com' }

        $result.OldThumbprint | Should -Be 'OLD1234'
        $result.NewThumbprint | Should -Be 'NEW5678'
        $result.Domain | Should -Be 'www.example.com'
    }

    It 'logs event 1001 with the domain and renewal details' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMERenewCertificate -Domain 'www.example.com' }

        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 1001 -and
            $EntryType -eq 'Information' -and
            $Message -like '*www.example.com*' -and
            $Message -like '*NEW5678*'
        }
    }

    It 'logs event 3003 and rethrows when the renewal fails' {
        Mock -ModuleName 'TU-ACME' Submit-Renewal { throw 'renewal exploded' }

        {
            InModuleScope 'TU-ACME' { Invoke-TUACMERenewCertificate -Domain 'www.example.com' }
        } | Should -Throw '*renewal exploded*'

        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 3003 -and $EntryType -eq 'Error'
        }
        Should -Invoke -ModuleName 'TU-ACME' Import-TUACMECertificate -Times 0 -Exactly
    }

    It 'logs event 3003 when the post-renewal import fails' {
        Mock -ModuleName 'TU-ACME' Import-TUACMECertificate { throw 'import exploded' }

        {
            InModuleScope 'TU-ACME' { Invoke-TUACMERenewCertificate -Domain 'www.example.com' }
        } | Should -Throw '*import exploded*'

        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 3003 -and $EntryType -eq 'Error'
        }
        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 0 -Exactly -ParameterFilter {
            $EventId -eq 1001
        }
    }
}
