BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Get-TUACMEKnownName (issue #21)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Get-TUACMELocalMachineName {
            [pscustomobject]@{ HostName = 'WEB01'; Fqdn = 'web01.corp.local' }
        }
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISBinding { @() }
    }

    It 'returns the FQDN first, then the short hostname' {
        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEKnownName })

        $result.Count | Should -Be 2
        $result[0].Name | Should -Be 'web01.corp.local'
        $result[0].Source | Should -Be 'FQDN'
        $result[1].Name | Should -Be 'WEB01'
        $result[1].Source | Should -Be 'Hostname'
    }

    It 'appends IIS bound host headers after the machine names' {
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISBinding {
            @(
                [pscustomobject]@{ HostHeader = 'intranet.corp.local' }
                [pscustomobject]@{ HostHeader = 'shop.corp.local' }
            )
        }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEKnownName })

        $result.Count | Should -Be 4
        $result[2].Name | Should -Be 'intranet.corp.local'
        $result[2].Source | Should -Be 'IIS host header'
        $result[3].Name | Should -Be 'shop.corp.local'
    }

    It 'de-duplicates names case-insensitively across sources' {
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISBinding {
            @(
                [pscustomobject]@{ HostHeader = 'WEB01.CORP.LOCAL' }
                [pscustomobject]@{ HostHeader = 'unique.corp.local' }
            )
        }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEKnownName })

        @($result | Where-Object { $_.Name -eq 'unique.corp.local' }).Count | Should -Be 1
        @($result | Where-Object { $_.Source -eq 'FQDN' }).Count | Should -Be 1
        # WEB01.CORP.LOCAL collapses into the existing FQDN entry.
        $result.Count | Should -Be 3
    }

    It 'skips empty host headers (HTTP bindings with no host header)' {
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISBinding {
            @(
                [pscustomobject]@{ HostHeader = '' }
                [pscustomobject]@{ HostHeader = 'named.corp.local' }
            )
        }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEKnownName })

        @($result | Where-Object { [string]::IsNullOrEmpty($_.Name) }).Count | Should -Be 0
        @($result | Where-Object { $_.Name -eq 'named.corp.local' }).Count | Should -Be 1
    }

    It 'omits the FQDN entry when the machine has no FQDN' {
        Mock -ModuleName 'TU-ACME' Get-TUACMELocalMachineName {
            [pscustomobject]@{ HostName = 'WEB01'; Fqdn = '' }
        }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEKnownName })

        $result.Count | Should -Be 1
        $result[0].Source | Should -Be 'Hostname'
    }

    It 'returns an empty array when nothing can be resolved' {
        Mock -ModuleName 'TU-ACME' Get-TUACMELocalMachineName {
            [pscustomobject]@{ HostName = ''; Fqdn = '' }
        }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEKnownName })

        $result.Count | Should -Be 0
    }
}
