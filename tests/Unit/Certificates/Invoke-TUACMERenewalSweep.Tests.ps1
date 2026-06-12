BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Invoke-TUACMERenewalSweep (UC-7.02 / AC-E.2, AC-E.3)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Get-TUACMECertificate {
            @(
                [pscustomobject]@{ MainDomain = 'expired.example.com'; Thumbprint = 'AAA'; NotAfter = (Get-Date).AddDays(-5) },
                [pscustomobject]@{ MainDomain = 'soon.example.com'; Thumbprint = 'BBB'; NotAfter = (Get-Date).AddDays(10) },
                [pscustomobject]@{ MainDomain = 'valid.example.com'; Thumbprint = 'CCC'; NotAfter = (Get-Date).AddDays(60) }
            )
        }
        Mock -ModuleName 'TU-ACME' Invoke-TUACMERenewCertificate {
            [pscustomobject]@{ Domain = $Domain; OldThumbprint = 'OLD'; NewThumbprint = 'NEW'; NotAfter = (Get-Date).AddDays(90) }
        }
    }

    It 'renews only certificates within the 30-day threshold' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMERenewalSweep }

        Should -Invoke -ModuleName 'TU-ACME' Invoke-TUACMERenewCertificate -Times 1 -Exactly -ParameterFilter {
            $Domain -eq 'expired.example.com'
        }
        Should -Invoke -ModuleName 'TU-ACME' Invoke-TUACMERenewCertificate -Times 1 -Exactly -ParameterFilter {
            $Domain -eq 'soon.example.com'
        }
        Should -Invoke -ModuleName 'TU-ACME' Invoke-TUACMERenewCertificate -Times 0 -Exactly -ParameterFilter {
            $Domain -eq 'valid.example.com'
        }
    }

    It 'honours a custom threshold' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMERenewalSweep -ThresholdDays 90 }

        Should -Invoke -ModuleName 'TU-ACME' Invoke-TUACMERenewCertificate -Times 3 -Exactly
    }

    It 'continues to the next certificate when one renewal fails' {
        Mock -ModuleName 'TU-ACME' Invoke-TUACMERenewCertificate {
            if ($Domain -eq 'expired.example.com') { throw 'renewal exploded' }
            [pscustomobject]@{ Domain = $Domain; OldThumbprint = 'OLD'; NewThumbprint = 'NEW'; NotAfter = (Get-Date).AddDays(90) }
        }

        $result = InModuleScope 'TU-ACME' { Invoke-TUACMERenewalSweep }

        Should -Invoke -ModuleName 'TU-ACME' Invoke-TUACMERenewCertificate -Times 2 -Exactly
        @($result.Failed).Count | Should -Be 1
        $result.Failed[0].Domain | Should -Be 'expired.example.com'
        @($result.Renewed).Count | Should -Be 1
    }

    It 'reports renewed certificates in the summary' {
        $result = InModuleScope 'TU-ACME' { Invoke-TUACMERenewalSweep }

        @($result.Renewed).Count | Should -Be 2
        @($result.Failed).Count | Should -Be 0
    }

    It 'does nothing when every certificate is still valid' {
        Mock -ModuleName 'TU-ACME' Get-TUACMECertificate {
            @([pscustomobject]@{ MainDomain = 'valid.example.com'; Thumbprint = 'CCC'; NotAfter = (Get-Date).AddDays(60) })
        }

        $result = InModuleScope 'TU-ACME' { Invoke-TUACMERenewalSweep }

        Should -Invoke -ModuleName 'TU-ACME' Invoke-TUACMERenewCertificate -Times 0 -Exactly
        @($result.Renewed).Count | Should -Be 0
    }
}
