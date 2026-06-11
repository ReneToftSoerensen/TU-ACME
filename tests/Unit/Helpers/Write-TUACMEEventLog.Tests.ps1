BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Write-TUACMEEventLog' -Tag 'Unit' {
    It 'is a silent no-op on non-Windows platforms' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $false }

        {
            InModuleScope 'TU-ACME' {
                Write-TUACMEEventLog -EventId 1010 -EntryType Information -Message 'test'
            }
        } | Should -Not -Throw
    }

    It 'never throws even when the event log write fails' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $true }

        {
            $null = InModuleScope 'TU-ACME' {
                Write-TUACMEEventLog -EventId 1010 -EntryType Information -Message 'test'
            } 3>&1
        } | Should -Not -Throw
    }

    It 'rejects entry types outside the registry levels' {
        {
            InModuleScope 'TU-ACME' {
                Write-TUACMEEventLog -EventId 1010 -EntryType 'Critical' -Message 'test'
            }
        } | Should -Throw
    }
}
