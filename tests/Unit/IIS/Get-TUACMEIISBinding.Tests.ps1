BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')

    function script:New-FakeBinding {
        param($Site, $Protocol, $BindingInformation, $Thumbprint)
        [pscustomobject]@{
            protocol           = $Protocol
            bindingInformation = $BindingInformation
            certificateHash    = $Thumbprint
            ItemXPath          = ("/system.applicationHost/sites/site[@name='{0}' and @id='1']" -f $Site)
        }
    }
}

Describe 'Get-TUACMEIISBinding (UC-9.01 / AC-G.1)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $true }
        Mock -ModuleName 'TU-ACME' Get-ChildItem { @() } -ParameterFilter { $Path -like 'Cert:*' }
    }

    It 'returns an empty list on non-Windows platforms' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $false }

        $result = InModuleScope 'TU-ACME' { Get-TUACMEIISBinding }

        $result | Should -BeNullOrEmpty
    }

    It 'returns an empty list when WebAdministration is unavailable' {
        Mock -ModuleName 'TU-ACME' Get-Command { $null } -ParameterFilter { $Name -eq 'Get-WebBinding' }

        $result = InModuleScope 'TU-ACME' { Get-TUACMEIISBinding }

        $result | Should -BeNullOrEmpty
    }

    It 'lists HTTP rows alongside HTTPS rows (no protocol filter)' {
        Mock -ModuleName 'TU-ACME' Get-WebBinding {
            @(
                (New-FakeBinding -Site 'Default Web Site' -Protocol 'http' -BindingInformation '*:80:' -Thumbprint ''),
                (New-FakeBinding -Site 'Default Web Site' -Protocol 'https' -BindingInformation '*:443:www.example.com' -Thumbprint 'AABBCC')
            )
        }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEIISBinding })

        $result.Count | Should -Be 2
        $result[0].Protocol | Should -Be 'http'
        $result[1].Protocol | Should -Be 'https'
    }

    It 'parses site name and host header from the binding' {
        Mock -ModuleName 'TU-ACME' Get-WebBinding {
            @((New-FakeBinding -Site 'Intranet' -Protocol 'https' -BindingInformation '*:443:portal.example.com' -Thumbprint 'AABBCC'))
        }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEIISBinding })

        $result[0].SiteName | Should -Be 'Intranet'
        $result[0].HostHeader | Should -Be 'portal.example.com'
        $result[0].Thumbprint | Should -Be 'AABBCC'
    }

    It 'resolves the certificate from WebHosting and returns the correct expiry' {
        Mock -ModuleName 'TU-ACME' Get-WebBinding {
            @((New-FakeBinding -Site 'S' -Protocol 'https' -BindingInformation '*:443:a.example.com' -Thumbprint 'AABBCC'))
        }
        $expectedExpiry = (Get-Date).AddDays(42)
        Mock -ModuleName 'TU-ACME' Get-ChildItem {
            @([pscustomobject]@{ Thumbprint = 'AABBCC'; NotAfter = $expectedExpiry; Extensions = @() })
        } -ParameterFilter { $Path -like '*WebHosting*' }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEIISBinding })

        $result[0].NotAfter | Should -Be $expectedExpiry
        # Both stores are enumerated once upfront for the cache (O(stores) not
        # O(bindings×stores)); the My store returns nothing so the lookup still
        # resolves to the WebHosting cert.
        Should -Invoke -ModuleName 'TU-ACME' Get-ChildItem -Times 1 -Exactly -ParameterFilter {
            $Path -like '*LocalMachine\My*'
        }
    }

    It 'parses host header correctly for IPv6 binding information' {
        Mock -ModuleName 'TU-ACME' Get-WebBinding {
            @((New-FakeBinding -Site 'S' -Protocol 'https' -BindingInformation '[::1]:443:ipv6.example.com' -Thumbprint ''))
        }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEIISBinding })

        $result[0].HostHeader | Should -Be 'ipv6.example.com'
        $result[0].BindingInformation | Should -Be '[::1]:443:ipv6.example.com'
    }

    It 'falls back to the My store when WebHosting has no match' {
        Mock -ModuleName 'TU-ACME' Get-WebBinding {
            @((New-FakeBinding -Site 'S' -Protocol 'https' -BindingInformation '*:443:a.example.com' -Thumbprint 'AABBCC'))
        }
        $expectedExpiry = (Get-Date).AddDays(42)
        Mock -ModuleName 'TU-ACME' Get-ChildItem {
            @([pscustomobject]@{ Thumbprint = 'AABBCC'; NotAfter = $expectedExpiry; Extensions = @() })
        } -ParameterFilter { $Path -like '*LocalMachine\My*' }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEIISBinding })

        $result[0].NotAfter | Should -Be $expectedExpiry
    }

    It 'leaves expiry and template blank when no certificate resolves' {
        Mock -ModuleName 'TU-ACME' Get-WebBinding {
            @((New-FakeBinding -Site 'S' -Protocol 'https' -BindingInformation '*:443:a.example.com' -Thumbprint 'MISSING'))
        }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEIISBinding })

        $result[0].NotAfter | Should -BeNullOrEmpty
        $result[0].Template | Should -Be ''
    }

    It 'normalises a byte[] certificateHash to uppercase hex for the cert store lookup' {
        # WebAdministration returns certificateHash as byte[] on some OS versions.
        $hashBytes = [byte[]]@(0xAA, 0xBB, 0xCC)
        $fakeBinding = [pscustomobject]@{
            protocol           = 'https'
            bindingInformation = '*:443:bytes.example.com'
            certificateHash    = $hashBytes
            ItemXPath          = "/system.applicationHost/sites/site[@name='S' and @id='1']"
        }
        Mock -ModuleName 'TU-ACME' Get-WebBinding { @($fakeBinding) }
        $expectedExpiry = (Get-Date).AddDays(42)
        Mock -ModuleName 'TU-ACME' Get-ChildItem {
            @([pscustomobject]@{ Thumbprint = 'AABBCC'; NotAfter = $expectedExpiry; Extensions = @() })
        } -ParameterFilter { $Path -like '*WebHosting*' }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEIISBinding })

        $result[0].Thumbprint | Should -Be 'AABBCC'
        $result[0].NotAfter | Should -Be $expectedExpiry
    }

    It 'extracts the AD CS template name from the certificate extension' {
        Mock -ModuleName 'TU-ACME' Get-WebBinding {
            @((New-FakeBinding -Site 'S' -Protocol 'https' -BindingInformation '*:443:a.example.com' -Thumbprint 'AABBCC'))
        }
        $extension = [pscustomobject]@{ Oid = [pscustomobject]@{ Value = '1.3.6.1.4.1.311.21.7' } }
        $extension | Add-Member -MemberType ScriptMethod -Name 'Format' -Value {
            param($MultiLine)
            'Template=WebServerV2(1.3.6.1.4.1.311.21.8.1234567.123), Major Version Number=100'
        }
        Mock -ModuleName 'TU-ACME' Get-ChildItem {
            @([pscustomobject]@{ Thumbprint = 'AABBCC'; NotAfter = (Get-Date).AddDays(42); Extensions = @($extension) })
        } -ParameterFilter { $Path -like '*WebHosting*' }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEIISBinding })

        $result[0].Template | Should -Be 'WebServerV2'
    }
}
