BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Get-TUACMEMachineName' -Tag 'Unit' {
    It 'returns an object exposing Fqdn and Hostname properties' {
        $result = InModuleScope 'TU-ACME' { Get-TUACMEMachineName }

        $result.PSObject.Properties.Name | Should -Contain 'Fqdn'
        $result.PSObject.Properties.Name | Should -Contain 'Hostname'
    }

    It 'sets Hostname to the local short host name' {
        $result = InModuleScope 'TU-ACME' { Get-TUACMEMachineName }

        $result.Hostname | Should -Be ([System.Net.Dns]::GetHostName())
    }

    It 'does not throw' {
        { InModuleScope 'TU-ACME' { Get-TUACMEMachineName } } | Should -Not -Throw
    }
}
