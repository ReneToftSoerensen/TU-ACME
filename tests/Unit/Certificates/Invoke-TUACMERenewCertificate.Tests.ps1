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

Describe 'Invoke-TUACMERenewCertificate force-renew (UC-6.03 / AC-D.5)' -Tag 'Unit' {
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

    It 'passes -NewKey to Submit-Renewal on force-renew' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMERenewCertificate -Domain 'www.example.com' -NewKey }

        Should -Invoke -ModuleName 'TU-ACME' Submit-Renewal -Times 1 -Exactly -ParameterFilter {
            $MainDomain -eq 'www.example.com' -and $Force -eq $true -and $NewKey -eq $true
        }
    }

    It 'logs event 1005 (not 1001) on force-renew' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMERenewCertificate -Domain 'www.example.com' -NewKey }

        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 1005 -and $EntryType -eq 'Information' -and $Message -like '*www.example.com*'
        }
        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 0 -Exactly -ParameterFilter {
            $EventId -eq 1001
        }
    }

    It 'logs event 3005 and rethrows when a force-renew fails' {
        Mock -ModuleName 'TU-ACME' Submit-Renewal { throw 'force-renew exploded' }

        {
            InModuleScope 'TU-ACME' { Invoke-TUACMERenewCertificate -Domain 'www.example.com' -NewKey }
        } | Should -Throw '*force-renew exploded*'

        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 3005 -and $EntryType -eq 'Error'
        }
    }
}

Describe 'Invoke-TUACMERenewCertificate IIS rebind (UC-9.02, UC-9.03)' -Tag 'Unit' {
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

    It 'rebinds IIS and deletes the old cert after a renewal' {
        Mock -ModuleName 'TU-ACME' Update-TUACMEIISBinding {
            [pscustomobject]@{ Updated = @([pscustomobject]@{ SiteName = 'S' }); Failed = @() }
        }
        Mock -ModuleName 'TU-ACME' Remove-TUACMEWebHostingCertificate { $true }

        $result = InModuleScope 'TU-ACME' { Invoke-TUACMERenewCertificate -Domain 'www.example.com' }

        Should -Invoke -ModuleName 'TU-ACME' Update-TUACMEIISBinding -Times 1 -Exactly -ParameterFilter {
            $OldThumbprint -eq 'OLD1234' -and $NewThumbprint -eq 'NEW5678'
        }
        Should -Invoke -ModuleName 'TU-ACME' Remove-TUACMEWebHostingCertificate -Times 1 -Exactly -ParameterFilter {
            $Thumbprint -eq 'OLD1234'
        }
        $result.RebindUpdated | Should -Be 1
    }

    It 'does not delete the old cert when no binding was updated' {
        Mock -ModuleName 'TU-ACME' Update-TUACMEIISBinding {
            [pscustomobject]@{ Updated = @(); Failed = @() }
        }
        Mock -ModuleName 'TU-ACME' Remove-TUACMEWebHostingCertificate { $true }

        $null = InModuleScope 'TU-ACME' { Invoke-TUACMERenewCertificate -Domain 'www.example.com' }

        Should -Invoke -ModuleName 'TU-ACME' Remove-TUACMEWebHostingCertificate -Times 0 -Exactly
    }

    It 'still reports success when the IIS rebind throws' {
        Mock -ModuleName 'TU-ACME' Update-TUACMEIISBinding { throw 'IIS exploded' }

        $result = InModuleScope 'TU-ACME' { Invoke-TUACMERenewCertificate -Domain 'www.example.com' }

        $result.NewThumbprint | Should -Be 'NEW5678'
        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 2001 -and $EntryType -eq 'Warning'
        }
    }
}
