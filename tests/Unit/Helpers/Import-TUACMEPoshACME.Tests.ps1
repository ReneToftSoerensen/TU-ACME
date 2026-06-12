BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Import-TUACMEPoshACME store rebind (UC-7.02)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Get-Module {
            [pscustomobject]@{ Name = 'Posh-ACME' }
        } -ParameterFilter { $Name -eq 'Posh-ACME' }
        Mock -ModuleName 'TU-ACME' Import-Module { } -ParameterFilter { $Name -eq 'Posh-ACME' }
    }

    It 'returns true without re-importing when already loaded' {
        $result = InModuleScope 'TU-ACME' { Import-TUACMEPoshACME }

        $result | Should -BeTrue
        Should -Invoke -ModuleName 'TU-ACME' Import-Module -Times 0 -Exactly -ParameterFilter {
            $Name -eq 'Posh-ACME'
        }
    }

    It 'force re-imports an already-loaded Posh-ACME when the store moved' {
        # Posh-ACME resolves POSHACME_HOME at import; without the rebind an
        # admin whose profile loaded Posh-ACME first orders into the
        # per-user store while the SYSTEM task renews from ProgramData.
        $result = InModuleScope 'TU-ACME' { Import-TUACMEPoshACME -ForceStoreRebind }

        $result | Should -BeTrue
        Should -Invoke -ModuleName 'TU-ACME' Import-Module -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'Posh-ACME' -and $Force -eq $true
        }
    }

    It 'downgrades a failed rebind to a warning' {
        Mock -ModuleName 'TU-ACME' Import-Module { throw 'module locked' } -ParameterFilter { $Name -eq 'Posh-ACME' }

        $result = InModuleScope 'TU-ACME' { Import-TUACMEPoshACME -ForceStoreRebind } 3>$null

        $result | Should -BeTrue
    }
}
