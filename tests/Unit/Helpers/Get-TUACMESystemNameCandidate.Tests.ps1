BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Get-TUACMESystemNameCandidate' -Tag 'Unit' {
    BeforeEach {
        # Default to a clean machine with no IIS bindings; individual tests
        # override these mocks as needed.
        Mock -ModuleName 'TU-ACME' Get-TUACMEMachineName {
            [pscustomobject]@{ Fqdn = 'host.example.com'; Hostname = 'host' }
        }
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISBinding { @() }
    }

    It 'returns the FQDN then the Hostname when there are no IIS bindings' {
        $result = @(InModuleScope 'TU-ACME' { Get-TUACMESystemNameCandidate })

        $result.Count | Should -Be 2
        $result[0].Name | Should -Be 'host.example.com'
        $result[0].Source | Should -Be 'FQDN'
        $result[1].Name | Should -Be 'host'
        $result[1].Source | Should -Be 'Hostname'
    }

    It 'appends IIS host headers after the machine names, in order' {
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISBinding {
            @(
                [pscustomobject]@{ HostHeader = 'portal.example.com' },
                [pscustomobject]@{ HostHeader = 'intranet.example.com' }
            )
        }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMESystemNameCandidate })

        $result.Count | Should -Be 4
        $result[0].Source | Should -Be 'FQDN'
        $result[1].Source | Should -Be 'Hostname'
        $result[2].Name | Should -Be 'portal.example.com'
        $result[2].Source | Should -Be 'IIS'
        $result[3].Name | Should -Be 'intranet.example.com'
        $result[3].Source | Should -Be 'IIS'
    }

    It 'de-duplicates case-insensitively, keeping the machine-name label' {
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISBinding {
            @(
                [pscustomobject]@{ HostHeader = 'HOST.EXAMPLE.COM' },
                [pscustomobject]@{ HostHeader = 'Host' },
                [pscustomobject]@{ HostHeader = 'extra.example.com' }
            )
        }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMESystemNameCandidate })

        $result.Count | Should -Be 3
        $result[0].Name | Should -Be 'host.example.com'
        $result[0].Source | Should -Be 'FQDN'
        $result[1].Name | Should -Be 'host'
        $result[1].Source | Should -Be 'Hostname'
        $result[2].Name | Should -Be 'extra.example.com'
        $result[2].Source | Should -Be 'IIS'
    }

    It 'drops empty/whitespace host headers and empty machine names' {
        Mock -ModuleName 'TU-ACME' Get-TUACMEMachineName {
            [pscustomobject]@{ Fqdn = ''; Hostname = 'host' }
        }
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISBinding {
            @(
                [pscustomobject]@{ HostHeader = '' },
                [pscustomobject]@{ HostHeader = '   ' },
                [pscustomobject]@{ HostHeader = 'real.example.com' }
            )
        }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMESystemNameCandidate })

        $result.Count | Should -Be 2
        $result[0].Name | Should -Be 'host'
        $result[0].Source | Should -Be 'Hostname'
        $result[1].Name | Should -Be 'real.example.com'
        $result[1].Source | Should -Be 'IIS'
    }

    It 'returns an empty array when there are no candidates' {
        Mock -ModuleName 'TU-ACME' Get-TUACMEMachineName {
            [pscustomobject]@{ Fqdn = ''; Hostname = '' }
        }
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISBinding { @() }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMESystemNameCandidate })

        $result.Count | Should -Be 0
    }
}
