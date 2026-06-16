BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Update-TUACMEIISBinding (UC-9.02 / AC-G.2, UC-9.03 / AC-G.3)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $true }
        Mock -ModuleName 'TU-ACME' Write-TUACMEEventLog { }
        Mock -ModuleName 'TU-ACME' Import-TUACMECertificate { 'NEWTHUMB' }
        Mock -ModuleName 'TU-ACME' Set-WebBinding { }
        # Default to the Windows PowerShell 5.1 (WebAdministration) write path;
        # the IISAdministration path is exercised by its own test (issue #16).
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISProvider { 'WebAdministration' }
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISBinding {
            @(
                [pscustomobject]@{ SiteName = 'Site1'; Protocol = 'https'; BindingInformation = '*:443:a.example.com'; HostHeader = 'a.example.com'; Thumbprint = 'OLD1' },
                [pscustomobject]@{ SiteName = 'Site2'; Protocol = 'https'; BindingInformation = '*:443:b.example.com'; HostHeader = 'b.example.com'; Thumbprint = 'OLD1' },
                [pscustomobject]@{ SiteName = 'Site3'; Protocol = 'https'; BindingInformation = '*:443:c.example.com'; HostHeader = 'c.example.com'; Thumbprint = 'OTHER' },
                [pscustomobject]@{ SiteName = 'Site4'; Protocol = 'https'; BindingInformation = '*:443:'; HostHeader = ''; Thumbprint = 'OLD4' }
            )
        }
    }

    It 'returns empty and does nothing on non-Windows platforms' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $false }

        $result = InModuleScope 'TU-ACME' {
            Update-TUACMEIISBinding -OldThumbprint 'OLD1' -NewThumbprint 'NEWTHUMB' -Certificate ([pscustomobject]@{ MainDomain = 'a'; PfxFullChain = 'x' })
        }

        @($result.Updated).Count | Should -Be 0
        Should -Invoke -ModuleName 'TU-ACME' Set-WebBinding -Times 0 -Exactly
    }

    It 'does not rebind or import when no binding matches the old thumbprint' {
        $result = InModuleScope 'TU-ACME' {
            Update-TUACMEIISBinding -OldThumbprint 'NOPE' -NewThumbprint 'NEWTHUMB' -Certificate ([pscustomobject]@{ MainDomain = 'a'; PfxFullChain = 'x' })
        }

        @($result.Updated).Count | Should -Be 0
        Should -Invoke -ModuleName 'TU-ACME' Import-TUACMECertificate -Times 0 -Exactly
        Should -Invoke -ModuleName 'TU-ACME' Set-WebBinding -Times 0 -Exactly
    }

    It 'imports the certificate into the WebHosting store before rebinding' {
        $null = InModuleScope 'TU-ACME' {
            Update-TUACMEIISBinding -OldThumbprint 'OLD1' -NewThumbprint 'NEWTHUMB' -Certificate ([pscustomobject]@{ MainDomain = 'a'; PfxFullChain = 'x' })
        }

        Should -Invoke -ModuleName 'TU-ACME' Import-TUACMECertificate -Times 1 -Exactly -ParameterFilter {
            $StoreName -contains 'WebHosting'
        }
    }

    It 'updates every binding sharing the old thumbprint in one pass and logs 1002' {
        $result = InModuleScope 'TU-ACME' {
            Update-TUACMEIISBinding -OldThumbprint 'OLD1' -NewThumbprint 'NEWTHUMB' -Certificate ([pscustomobject]@{ MainDomain = 'a'; PfxFullChain = 'x' })
        }

        @($result.Updated).Count | Should -Be 2
        Should -Invoke -ModuleName 'TU-ACME' Set-WebBinding -ParameterFilter {
            $PropertyName -eq 'certificateHash' -and $Value -eq 'NEWTHUMB'
        }
        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 2 -Exactly -ParameterFilter {
            $EventId -eq 1002 -and $EntryType -eq 'Information'
        }
    }

    It 'selects a specific binding by site and binding information (manual rebind)' {
        $result = InModuleScope 'TU-ACME' {
            Update-TUACMEIISBinding -SiteName 'Site3' -BindingInformation '*:443:c.example.com' -NewThumbprint 'NEWTHUMB' -Certificate ([pscustomobject]@{ MainDomain = 'c'; PfxFullChain = 'x' })
        }

        @($result.Updated).Count | Should -Be 1
    }

    It 'rebinds a binding with an empty host header by binding information' {
        $result = InModuleScope 'TU-ACME' {
            Update-TUACMEIISBinding -SiteName 'Site4' -BindingInformation '*:443:' -NewThumbprint 'NEWTHUMB' -Certificate ([pscustomobject]@{ MainDomain = 'x'; PfxFullChain = 'x' })
        }

        @($result.Updated).Count | Should -Be 1
    }

    It 'skips rebinding (and importing) when no IIS provider is available' {
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISProvider { $null }

        $result = InModuleScope 'TU-ACME' {
            Update-TUACMEIISBinding -OldThumbprint 'OLD1' -NewThumbprint 'NEWTHUMB' -Certificate ([pscustomobject]@{ MainDomain = 'a'; PfxFullChain = 'x' })
        }

        @($result.Updated).Count | Should -Be 0
        Should -Invoke -ModuleName 'TU-ACME' Import-TUACMECertificate -Times 0 -Exactly
        Should -Invoke -ModuleName 'TU-ACME' Set-WebBinding -Times 0 -Exactly
    }

    It 'rebinds via IISAdministration when running under PowerShell 7 (issue #16)' {
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISProvider { 'IISAdministration' }
        Mock -ModuleName 'TU-ACME' Set-TUACMEIISBindingCertificate { }

        $result = InModuleScope 'TU-ACME' {
            Update-TUACMEIISBinding -OldThumbprint 'OLD1' -NewThumbprint 'NEWTHUMB' -Certificate ([pscustomobject]@{ MainDomain = 'a'; PfxFullChain = 'x' })
        }

        @($result.Updated).Count | Should -Be 2
        Should -Invoke -ModuleName 'TU-ACME' Set-TUACMEIISBindingCertificate -Times 2 -Exactly -ParameterFilter {
            $Thumbprint -eq 'NEWTHUMB' -and $StoreName -eq 'WebHosting'
        }
        Should -Invoke -ModuleName 'TU-ACME' Set-WebBinding -Times 0 -Exactly
    }

    It 'logs 2001 and continues when a single binding fails to rebind' {
        Mock -ModuleName 'TU-ACME' Set-WebBinding {
            if ($BindingInformation -eq '*:443:a.example.com' -and $PropertyName -eq 'certificateHash') {
                throw 'binding is in use'
            }
        }

        $result = InModuleScope 'TU-ACME' {
            Update-TUACMEIISBinding -OldThumbprint 'OLD1' -NewThumbprint 'NEWTHUMB' -Certificate ([pscustomobject]@{ MainDomain = 'a'; PfxFullChain = 'x' })
        }

        @($result.Updated).Count | Should -Be 1
        @($result.Failed).Count | Should -Be 1
        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 2001 -and $EntryType -eq 'Warning'
        }
    }
}
