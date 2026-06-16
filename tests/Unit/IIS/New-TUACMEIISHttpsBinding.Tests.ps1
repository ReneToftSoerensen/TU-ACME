BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'New-TUACMEIISHttpsBinding (UC-9.04 / AC-G.4)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $true }
        Mock -ModuleName 'TU-ACME' Write-TUACMEEventLog { }
        Mock -ModuleName 'TU-ACME' Invoke-TUACMEOrderCertificate {
            [pscustomobject]@{ Domain = $Domain[0]; Thumbprint = 'ORDERED'; NotAfter = (Get-Date).AddDays(90) }
        }
        Mock -ModuleName 'TU-ACME' Get-PACertificate { [pscustomobject]@{ MainDomain = 'site.example.com'; PfxFullChain = 'x'; PfxPass = $null } }
        Mock -ModuleName 'TU-ACME' Import-TUACMECertificate { 'NEWTHUMB' }
        Mock -ModuleName 'TU-ACME' New-WebBinding { }
        Mock -ModuleName 'TU-ACME' Set-WebBinding { }
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISBinding { @() }
    }

    It 'dry-run orders against staging and makes no import and no IIS changes' {
        $result = InModuleScope 'TU-ACME' {
            New-TUACMEIISHttpsBinding -SiteName 'Site1' -Domain 'site.example.com' -San @('www.example.com') -Port 443 -HostHeader 'site.example.com' -DryRun
        }

        $result.DryRun | Should -BeTrue
        $result.BindingCreated | Should -BeFalse
        Should -Invoke -ModuleName 'TU-ACME' Invoke-TUACMEOrderCertificate -Times 1 -Exactly -ParameterFilter {
            $DryRun.IsPresent -eq $true
        }
        Should -Invoke -ModuleName 'TU-ACME' Import-TUACMECertificate -Times 0 -Exactly
        Should -Invoke -ModuleName 'TU-ACME' New-WebBinding -Times 0 -Exactly
        Should -Invoke -ModuleName 'TU-ACME' Set-WebBinding -Times 0 -Exactly
    }

    It 'orders with the CN plus the SANs on the production path' {
        $null = InModuleScope 'TU-ACME' {
            New-TUACMEIISHttpsBinding -SiteName 'Site1' -Domain 'site.example.com' -San @('www.example.com', 'alt.example.com') -Port 443 -HostHeader 'site.example.com'
        }

        Should -Invoke -ModuleName 'TU-ACME' Invoke-TUACMEOrderCertificate -Times 1 -Exactly -ParameterFilter {
            $Domain[0] -eq 'site.example.com' -and
            ($Domain -contains 'www.example.com') -and
            ($Domain -contains 'alt.example.com')
        }
    }

    It 'imports the certificate into both stores and creates the binding with the cert hash and logs 1002' {
        $result = InModuleScope 'TU-ACME' {
            New-TUACMEIISHttpsBinding -SiteName 'Site1' -Domain 'site.example.com' -Port 443 -HostHeader 'site.example.com'
        }

        $result.BindingCreated | Should -BeTrue
        $result.Thumbprint | Should -Be 'NEWTHUMB'
        Should -Invoke -ModuleName 'TU-ACME' Import-TUACMECertificate -Times 1 -Exactly -ParameterFilter {
            ($StoreName -contains 'My') -and ($StoreName -contains 'WebHosting')
        }
        Should -Invoke -ModuleName 'TU-ACME' New-WebBinding -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'Site1' -and $Protocol -eq 'https' -and $Port -eq 443
        }
        Should -Invoke -ModuleName 'TU-ACME' Set-WebBinding -ParameterFilter {
            $PropertyName -eq 'certificateHash' -and $Value -eq 'NEWTHUMB'
        }
        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 1002 -and $EntryType -eq 'Information'
        }
    }

    It 'uses SNI flags when a host header is present' {
        $null = InModuleScope 'TU-ACME' {
            New-TUACMEIISHttpsBinding -SiteName 'Site1' -Domain 'site.example.com' -Port 443 -HostHeader 'site.example.com'
        }

        Should -Invoke -ModuleName 'TU-ACME' New-WebBinding -Times 1 -Exactly -ParameterFilter {
            $SslFlags -eq 1 -and $HostHeader -eq 'site.example.com'
        }
    }

    It 'updates an existing binding instead of creating a duplicate' {
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISBinding {
            @(
                [pscustomobject]@{ SiteName = 'Site1'; Protocol = 'https'; BindingInformation = '*:443:site.example.com'; HostHeader = 'site.example.com'; Thumbprint = 'OLD' }
            )
        }

        $result = InModuleScope 'TU-ACME' {
            New-TUACMEIISHttpsBinding -SiteName 'Site1' -Domain 'site.example.com' -Port 443 -HostHeader 'site.example.com'
        }

        $result.BindingUpdated | Should -BeTrue
        $result.BindingCreated | Should -BeFalse
        Should -Invoke -ModuleName 'TU-ACME' New-WebBinding -Times 0 -Exactly
        Should -Invoke -ModuleName 'TU-ACME' Set-WebBinding -ParameterFilter {
            $PropertyName -eq 'certificateHash' -and $Value -eq 'NEWTHUMB'
        }
    }

    It 'makes no binding calls on non-Windows platforms' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $false }
        Mock -ModuleName 'TU-ACME' Write-Host { }

        $result = InModuleScope 'TU-ACME' {
            New-TUACMEIISHttpsBinding -SiteName 'Site1' -Domain 'site.example.com' -Port 443 -HostHeader 'site.example.com'
        }

        $result.BindingCreated | Should -BeFalse
        Should -Invoke -ModuleName 'TU-ACME' Import-TUACMECertificate -Times 0 -Exactly
        Should -Invoke -ModuleName 'TU-ACME' New-WebBinding -Times 0 -Exactly
        Should -Invoke -ModuleName 'TU-ACME' Set-WebBinding -Times 0 -Exactly
    }

    It 'makes no binding calls when WebAdministration is unavailable' {
        Mock -ModuleName 'TU-ACME' Get-Command { $null } -ParameterFilter { $Name -eq 'New-WebBinding' }
        Mock -ModuleName 'TU-ACME' Write-Host { }

        $result = InModuleScope 'TU-ACME' {
            New-TUACMEIISHttpsBinding -SiteName 'Site1' -Domain 'site.example.com' -Port 443 -HostHeader 'site.example.com'
        }

        $result.BindingCreated | Should -BeFalse
        Should -Invoke -ModuleName 'TU-ACME' New-WebBinding -Times 0 -Exactly
        Should -Invoke -ModuleName 'TU-ACME' Set-WebBinding -Times 0 -Exactly
    }
}
