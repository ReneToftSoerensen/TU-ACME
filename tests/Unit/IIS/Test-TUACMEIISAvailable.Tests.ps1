BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Test-TUACMEIISAvailable (issue #16)' -Tag 'Unit' {
    It 'is false on non-Windows platforms' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $false }
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISProvider { 'WebAdministration' }

        InModuleScope 'TU-ACME' { Test-TUACMEIISAvailable } | Should -BeFalse
    }

    It 'is false on Windows when no IIS provider is available' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $true }
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISProvider { $null }

        InModuleScope 'TU-ACME' { Test-TUACMEIISAvailable } | Should -BeFalse
    }

    It 'is true on Windows with an IIS provider available' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $true }
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISProvider { 'IISAdministration' }

        InModuleScope 'TU-ACME' { Test-TUACMEIISAvailable } | Should -BeTrue
    }
}
