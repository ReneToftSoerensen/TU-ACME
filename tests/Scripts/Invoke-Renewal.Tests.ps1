BeforeAll {
    . (Join-Path (Split-Path -Parent $PSScriptRoot) 'Bootstrap.ps1')
    . (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'Fixtures') 'FakeObjects.ps1')

    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:scriptPath = Join-Path (Join-Path (Join-Path $repoRoot 'TU-ACME') 'Scripts') 'Invoke-Renewal.ps1'
}

Describe 'Invoke-Renewal.ps1 (UC-11.05, UC-7.02 / AC-I.5, AC-E.2, AC-E.3)' -Tag 'Scripts' {
    BeforeEach {
        # The module is already loaded by Bootstrap, so the script skips its
        # own import and the sweep runs against these module-scoped mocks.
        Mock -ModuleName 'TU-ACME' Use-TUACMEProdAccount { 'https://previous.example/dir' }
        Mock -ModuleName 'TU-ACME' Write-TUACMEEventLog { }
        Mock -ModuleName 'TU-ACME' Get-TUACMECertificate {
            @(
                (New-TUACMEFakeCertificate -MainDomain 'expired.example.com' -Thumbprint 'AAA' -DaysUntilExpiry -5),
                (New-TUACMEFakeCertificate -MainDomain 'soon.example.com' -Thumbprint 'BBB' -DaysUntilExpiry 10),
                (New-TUACMEFakeCertificate -MainDomain 'valid.example.com' -Thumbprint 'CCC' -DaysUntilExpiry 60)
            )
        }
        Mock -ModuleName 'TU-ACME' Get-PACertificate {
            New-TUACMEFakeCertificate -MainDomain $MainDomain -Thumbprint 'OLD' -DaysUntilExpiry 5
        }
        Mock -ModuleName 'TU-ACME' Submit-Renewal {
            New-TUACMEFakeCertificate -MainDomain $MainDomain -Thumbprint 'NEW' -DaysUntilExpiry 90
        }
        Mock -ModuleName 'TU-ACME' Import-TUACMECertificate { 'NEW' }
    }

    It 'renews exactly the certificates within the threshold' {
        & $script:scriptPath

        Should -Invoke -ModuleName 'TU-ACME' Submit-Renewal -Times 1 -Exactly -ParameterFilter {
            $MainDomain -eq 'expired.example.com'
        }
        Should -Invoke -ModuleName 'TU-ACME' Submit-Renewal -Times 1 -Exactly -ParameterFilter {
            $MainDomain -eq 'soon.example.com'
        }
        Should -Invoke -ModuleName 'TU-ACME' Submit-Renewal -Times 2 -Exactly
    }

    It 'imports every renewed certificate to LocalMachine\My (AC-E.3)' {
        & $script:scriptPath

        Should -Invoke -ModuleName 'TU-ACME' Import-TUACMECertificate -Times 2 -Exactly
    }

    It 'logs event 1001 per renewed certificate' {
        & $script:scriptPath

        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 2 -Exactly -ParameterFilter {
            $EventId -eq 1001 -and $EntryType -eq 'Information'
        }
    }

    It 'produces no console output (AC-E.2)' {
        $output = @(& $script:scriptPath *>&1)

        $output.Count | Should -Be 0
    }

    It 'continues past a failing certificate and logs 3003 for it' {
        Mock -ModuleName 'TU-ACME' Submit-Renewal {
            if ($MainDomain -eq 'expired.example.com') {
                throw 'renewal exploded'
            }
            New-TUACMEFakeCertificate -MainDomain $MainDomain -Thumbprint 'NEW' -DaysUntilExpiry 90
        }

        & $script:scriptPath

        Should -Invoke -ModuleName 'TU-ACME' Submit-Renewal -Times 2 -Exactly
        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 3003 -and $EntryType -eq 'Error' -and $Message -like '*expired.example.com*'
        }
        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 1001
        }
    }

    It 'logs event 3001 when the sweep aborts fatally' {
        Mock -ModuleName 'TU-ACME' Get-TUACMECertificate { throw 'store unreadable' }

        & $script:scriptPath

        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 3001 -and $EntryType -eq 'Error' -and $Message -like '*store unreadable*'
        }
    }

    It 'does not prompt the user (AC-E.2)' {
        Mock -ModuleName 'TU-ACME' Read-Host { throw 'renewal script must never prompt' }

        { & $script:scriptPath } | Should -Not -Throw
    }

    It 'rebinds IIS and cleans up old certs during the sweep (UC-9.02, UC-9.03)' {
        Mock -ModuleName 'TU-ACME' Update-TUACMEIISBinding {
            [pscustomobject]@{ Updated = @([pscustomobject]@{ SiteName = 'S' }); Failed = @() }
        }
        Mock -ModuleName 'TU-ACME' Remove-TUACMEWebHostingCertificate { $true }

        & $script:scriptPath

        Should -Invoke -ModuleName 'TU-ACME' Update-TUACMEIISBinding -Times 2 -Exactly
        Should -Invoke -ModuleName 'TU-ACME' Remove-TUACMEWebHostingCertificate -Times 2 -Exactly
    }

    It 'continues the sweep when a rebind throws (UC-9.03)' {
        Mock -ModuleName 'TU-ACME' Update-TUACMEIISBinding { throw 'IIS exploded' }

        & $script:scriptPath

        Should -Invoke -ModuleName 'TU-ACME' Import-TUACMECertificate -Times 2 -Exactly
        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -ParameterFilter {
            $EventId -eq 2001 -and $EntryType -eq 'Warning'
        }
    }
}
