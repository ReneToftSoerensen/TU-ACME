BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Set-TUACMEIISBindingCertificate (issue #16)' -Tag 'Unit' {
    It 'sets certificateHash and store on the matching binding, then commits' {
        InModuleScope 'TU-ACME' {
            $script:committed = $false
            $script:fakeBinding = $null
            Mock Get-IISServerManager {
                $b = [pscustomobject]@{
                    Protocol             = 'https'
                    BindingInformation   = '*:443:a.example.com'
                    CertificateHash      = $null
                    CertificateStoreName = $null
                }
                $site = [pscustomobject]@{ Bindings = @($b) }
                $mgr = [pscustomobject]@{ Sites = @{ 'Site1' = $site } }
                $mgr | Add-Member -MemberType ScriptMethod -Name 'CommitChanges' -Value { $script:committed = $true }
                $script:fakeBinding = $b
                $mgr
            }

            Set-TUACMEIISBindingCertificate -SiteName 'Site1' -BindingInformation '*:443:a.example.com' -Thumbprint 'AABBCC'

            $script:fakeBinding.CertificateStoreName | Should -Be 'WebHosting'
            $script:fakeBinding.CertificateHash[0] | Should -Be 170
            $script:fakeBinding.CertificateHash[2] | Should -Be 204
            $script:committed | Should -BeTrue
        }
    }

    It 'honours an explicit store name' {
        InModuleScope 'TU-ACME' {
            $script:fakeBinding = $null
            Mock Get-IISServerManager {
                $b = [pscustomobject]@{
                    Protocol             = 'https'
                    BindingInformation   = '*:443:a.example.com'
                    CertificateHash      = $null
                    CertificateStoreName = $null
                }
                $site = [pscustomobject]@{ Bindings = @($b) }
                $mgr = [pscustomobject]@{ Sites = @{ 'Site1' = $site } }
                $mgr | Add-Member -MemberType ScriptMethod -Name 'CommitChanges' -Value { }
                $script:fakeBinding = $b
                $mgr
            }

            Set-TUACMEIISBindingCertificate -SiteName 'Site1' -BindingInformation '*:443:a.example.com' -Thumbprint 'AABBCC' -StoreName 'My'

            $script:fakeBinding.CertificateStoreName | Should -Be 'My'
        }
    }

    It 'throws when the site is not found' {
        InModuleScope 'TU-ACME' {
            Mock Get-IISServerManager { [pscustomobject]@{ Sites = @{} } }

            { Set-TUACMEIISBindingCertificate -SiteName 'Missing' -BindingInformation '*:443:a.example.com' -Thumbprint 'AABBCC' } |
                Should -Throw
        }
    }

    It 'throws and does not commit when the binding is not found on the site' {
        InModuleScope 'TU-ACME' {
            $script:committed = $false
            Mock Get-IISServerManager {
                $b = [pscustomobject]@{
                    Protocol             = 'https'
                    BindingInformation   = '*:443:other.example.com'
                    CertificateHash      = $null
                    CertificateStoreName = $null
                }
                $site = [pscustomobject]@{ Bindings = @($b) }
                $mgr = [pscustomobject]@{ Sites = @{ 'Site1' = $site } }
                $mgr | Add-Member -MemberType ScriptMethod -Name 'CommitChanges' -Value { $script:committed = $true }
                $mgr
            }

            { Set-TUACMEIISBindingCertificate -SiteName 'Site1' -BindingInformation '*:443:a.example.com' -Thumbprint 'AABBCC' } |
                Should -Throw
            $script:committed | Should -BeFalse
        }
    }

    It 'updates only the HTTPS binding when an HTTP binding shares the same BindingInformation' {
        InModuleScope 'TU-ACME' {
            $script:httpsBinding = $null
            $script:httpBinding = $null
            Mock Get-IISServerManager {
                # HTTP listed first so the old (protocol-agnostic) match would
                # have written to it before reaching the HTTPS binding.
                $http = [pscustomobject]@{
                    Protocol             = 'http'
                    BindingInformation   = '*:443:a.example.com'
                    CertificateHash      = $null
                    CertificateStoreName = $null
                }
                $https = [pscustomobject]@{
                    Protocol             = 'https'
                    BindingInformation   = '*:443:a.example.com'
                    CertificateHash      = $null
                    CertificateStoreName = $null
                }
                $site = [pscustomobject]@{ Bindings = @($http, $https) }
                $mgr = [pscustomobject]@{ Sites = @{ 'Site1' = $site } }
                $mgr | Add-Member -MemberType ScriptMethod -Name 'CommitChanges' -Value { }
                $script:httpBinding = $http
                $script:httpsBinding = $https
                $mgr
            }

            Set-TUACMEIISBindingCertificate -SiteName 'Site1' -BindingInformation '*:443:a.example.com' -Thumbprint 'AABBCC'

            $script:httpsBinding.CertificateStoreName | Should -Be 'WebHosting'
            $script:httpBinding.CertificateStoreName | Should -BeNullOrEmpty
            $script:httpBinding.CertificateHash | Should -BeNullOrEmpty
        }
    }
}
