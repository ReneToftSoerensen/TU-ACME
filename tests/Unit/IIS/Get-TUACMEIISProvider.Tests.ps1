BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Get-TUACMEIISProvider (issue #16)' -Tag 'Unit' {
    It 'prefers IISAdministration on PowerShell 7 (Core) when it is available' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsCoreEdition { $true }
        Mock -ModuleName 'TU-ACME' Get-Command { [pscustomobject]@{ Name = 'Get-IISSite' } } -ParameterFilter { $Name -eq 'Get-IISSite' }
        Mock -ModuleName 'TU-ACME' Get-Command { [pscustomobject]@{ Name = 'Get-WebBinding' } } -ParameterFilter { $Name -eq 'Get-WebBinding' }

        InModuleScope 'TU-ACME' { Get-TUACMEIISProvider } | Should -Be 'IISAdministration'
    }

    It 'falls back to WebAdministration on Core when IISAdministration is absent' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsCoreEdition { $true }
        Mock -ModuleName 'TU-ACME' Get-Command { $null } -ParameterFilter { $Name -eq 'Get-IISSite' }
        Mock -ModuleName 'TU-ACME' Get-Command { [pscustomobject]@{ Name = 'Get-WebBinding' } } -ParameterFilter { $Name -eq 'Get-WebBinding' }

        InModuleScope 'TU-ACME' { Get-TUACMEIISProvider } | Should -Be 'WebAdministration'
    }

    It 'prefers WebAdministration on Windows PowerShell 5.1 (Desktop)' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsCoreEdition { $false }
        Mock -ModuleName 'TU-ACME' Get-Command { [pscustomobject]@{ Name = 'Get-IISSite' } } -ParameterFilter { $Name -eq 'Get-IISSite' }
        Mock -ModuleName 'TU-ACME' Get-Command { [pscustomobject]@{ Name = 'Get-WebBinding' } } -ParameterFilter { $Name -eq 'Get-WebBinding' }

        InModuleScope 'TU-ACME' { Get-TUACMEIISProvider } | Should -Be 'WebAdministration'
    }

    It 'falls back to IISAdministration on Desktop when WebAdministration is absent' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsCoreEdition { $false }
        Mock -ModuleName 'TU-ACME' Get-Command { [pscustomobject]@{ Name = 'Get-IISSite' } } -ParameterFilter { $Name -eq 'Get-IISSite' }
        Mock -ModuleName 'TU-ACME' Get-Command { $null } -ParameterFilter { $Name -eq 'Get-WebBinding' }

        InModuleScope 'TU-ACME' { Get-TUACMEIISProvider } | Should -Be 'IISAdministration'
    }

    It 'returns $null when neither provider is available' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsCoreEdition { $true }
        Mock -ModuleName 'TU-ACME' Get-Command { $null } -ParameterFilter { $Name -eq 'Get-IISSite' }
        Mock -ModuleName 'TU-ACME' Get-Command { $null } -ParameterFilter { $Name -eq 'Get-WebBinding' }
        Mock -ModuleName 'TU-ACME' Get-Module { $null }
        Mock -ModuleName 'TU-ACME' Import-Module { }

        InModuleScope 'TU-ACME' { Get-TUACMEIISProvider } | Should -BeNullOrEmpty
    }
}
