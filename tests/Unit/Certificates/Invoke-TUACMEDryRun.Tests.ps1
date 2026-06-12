BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Invoke-TUACMEDryRun (UC-3.01 / AC-B.3, AC-B.4)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Use-TUACMEStagingAccount { 'https://prod.example/dir' }
        Mock -ModuleName 'TU-ACME' Use-TUACMEProdAccount { 'https://staging.example/dir' }
        Mock -ModuleName 'TU-ACME' Write-TUACMEEventLog { }
    }

    It 'switches to the staging account before running the operation' {
        $null = InModuleScope 'TU-ACME' {
            Invoke-TUACMEDryRun -Operation { 'ok' }
        }

        Should -Invoke -ModuleName 'TU-ACME' Use-TUACMEStagingAccount -Times 1 -Exactly
    }

    It 'returns the operation result' {
        $result = InModuleScope 'TU-ACME' {
            Invoke-TUACMEDryRun -Operation { 'operation-result' }
        }

        $result | Should -Be 'operation-result'
    }

    It 'restores the prod account after a successful run' {
        $null = InModuleScope 'TU-ACME' {
            Invoke-TUACMEDryRun -Operation { 'ok' }
        }

        Should -Invoke -ModuleName 'TU-ACME' Use-TUACMEProdAccount -Times 1 -Exactly
    }

    It 'restores the prod account even when the operation throws' {
        {
            InModuleScope 'TU-ACME' {
                Invoke-TUACMEDryRun -Operation { throw 'order exploded' }
            }
        } | Should -Throw '*order exploded*'

        Should -Invoke -ModuleName 'TU-ACME' Use-TUACMEProdAccount -Times 1 -Exactly
    }

    It 'logs event 1006 on success' {
        $null = InModuleScope 'TU-ACME' {
            Invoke-TUACMEDryRun -Operation { 'ok' }
        }

        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 1006 -and $EntryType -eq 'Information'
        }
    }

    It 'does not log event 1006 when the operation fails' {
        {
            InModuleScope 'TU-ACME' {
                Invoke-TUACMEDryRun -Operation { throw 'order exploded' }
            }
        } | Should -Throw

        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 0 -Exactly -ParameterFilter {
            $EventId -eq 1006
        }
    }
}
