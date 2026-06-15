BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Get-TUACMERenewalStatusData (UC-12.02 / AC-J.4)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Get-TUACMECertificate {
            @(
                [pscustomobject]@{ MainDomain = 'valid.example.com'; NotAfter = (Get-Date).AddDays(60); NotBefore = (Get-Date).AddDays(-30) },
                [pscustomobject]@{ MainDomain = 'overdue.example.com'; NotAfter = (Get-Date).AddDays(-5); NotBefore = (Get-Date).AddDays(-95) },
                [pscustomobject]@{ MainDomain = 'fresh.example.com'; NotAfter = (Get-Date).AddDays(89); NotBefore = (Get-Date).AddHours(-2) }
            )
        }
    }

    It 'sorts rows by days remaining (fewest first)' {
        $data = InModuleScope 'TU-ACME' { Get-TUACMERenewalStatusData }

        $data.Rows[0].Domain | Should -Be 'overdue.example.com'
    }

    It 'flags overdue certificates' {
        $data = InModuleScope 'TU-ACME' { Get-TUACMERenewalStatusData }

        ($data.Rows | Where-Object { $_.Domain -eq 'overdue.example.com' }).Overdue | Should -BeTrue
    }

    It 'estimates next renewal as expiry minus the threshold' {
        $data = InModuleScope 'TU-ACME' { Get-TUACMERenewalStatusData -RenewThresholdDays 30 }

        $row = $data.Rows | Where-Object { $_.Domain -eq 'valid.example.com' }
        $row.NextRenewal | Should -Be (([datetime]$row.NotAfter).AddDays(-30))
    }

    It 'summarises totals, valid, overdue, and renewed-in-24h' {
        $data = InModuleScope 'TU-ACME' { Get-TUACMERenewalStatusData }

        $data.Total | Should -Be 3
        $data.Overdue | Should -Be 1
        $data.Valid | Should -Be 2
        $data.RenewedLast24h | Should -Be 1
    }
}
