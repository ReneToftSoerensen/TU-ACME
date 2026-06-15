BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Remove-TUACMEWebHostingCertificate (UC-9.03 / AC-G.3)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $true }
        Mock -ModuleName 'TU-ACME' Write-TUACMEEventLog { }
        Mock -ModuleName 'TU-ACME' Test-Path { $true } -ParameterFilter { $LiteralPath -like 'Cert:*' }
        Mock -ModuleName 'TU-ACME' Remove-Item { } -ParameterFilter { $LiteralPath -like 'Cert:*' }
    }

    It 'returns false on non-Windows platforms' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $false }

        InModuleScope 'TU-ACME' { Remove-TUACMEWebHostingCertificate -Thumbprint 'ABC' } | Should -BeFalse
    }

    It 'removes the cert from the WebHosting store and returns true' {
        $result = InModuleScope 'TU-ACME' { Remove-TUACMEWebHostingCertificate -Thumbprint 'ABC123' }

        $result | Should -BeTrue
        Should -Invoke -ModuleName 'TU-ACME' Remove-Item -Times 1 -Exactly -ParameterFilter {
            $LiteralPath -like '*WebHosting\ABC123'
        }
    }

    It 'logs 2001 and returns false when deletion fails' {
        Mock -ModuleName 'TU-ACME' Remove-Item { throw 'cert in use' } -ParameterFilter { $LiteralPath -like 'Cert:*' }

        $result = InModuleScope 'TU-ACME' { Remove-TUACMEWebHostingCertificate -Thumbprint 'ABC123' }

        $result | Should -BeFalse
        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 2001 -and $EntryType -eq 'Warning'
        }
    }
}
