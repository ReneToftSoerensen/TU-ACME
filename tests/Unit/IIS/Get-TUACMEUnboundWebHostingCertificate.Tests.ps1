BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Get-TUACMEUnboundWebHostingCertificate (UC-9.03 / AC-G.3)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $true }
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISBinding {
            @([pscustomobject]@{ Thumbprint = 'BOUND1'; Protocol = 'https' })
        }
        Mock -ModuleName 'TU-ACME' Get-ChildItem {
            @(
                [pscustomobject]@{ Thumbprint = 'BOUND1'; NotAfter = (Get-Date).AddDays(30) },
                [pscustomobject]@{ Thumbprint = 'ORPHAN2'; NotAfter = (Get-Date).AddDays(10) }
            )
        } -ParameterFilter { $Path -like '*WebHosting*' }
    }

    It 'returns empty on non-Windows platforms' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $false }

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEUnboundWebHostingCertificate })

        $result.Count | Should -Be 0
    }

    It 'returns only WebHosting certs not referenced by any binding' {
        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEUnboundWebHostingCertificate })

        $result.Count | Should -Be 1
        $result[0].Thumbprint | Should -Be 'ORPHAN2'
    }
}
