BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Get-TUACMELocalMachineName (issue #21)' -Tag 'Unit' {
    It 'returns an object exposing HostName and Fqdn' {
        $result = InModuleScope 'TU-ACME' { Get-TUACMELocalMachineName }

        $result.PSObject.Properties.Name | Should -Contain 'HostName'
        $result.PSObject.Properties.Name | Should -Contain 'Fqdn'
        [string]$result.HostName | Should -Not -BeNullOrEmpty
    }

    It 'returns an empty Fqdn for a single-label (non-dotted) resolution' {
        # GetHostEntry echoing the short hostname must not be reported as an FQDN.
        $result = InModuleScope 'TU-ACME' { Get-TUACMELocalMachineName }

        if (-not [string]::IsNullOrEmpty($result.Fqdn)) {
            $result.Fqdn | Should -Match '\.'
        }
    }
}
