BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Show-TUACMERenewalStatus (UC-12.02 / AC-J.4)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Clear-Host { }
        Mock -ModuleName 'TU-ACME' Write-Host { }
        Mock -ModuleName 'TU-ACME' Get-TUACMERenewalStatusData {
            [pscustomobject]@{
                Rows           = @(
                    [pscustomobject]@{
                        Domain        = 'overdue.example.com'
                        NotAfter      = (Get-Date).AddDays(-5)
                        DaysRemaining = -5
                        LastRenewal   = (Get-Date).AddDays(-95)
                        NextRenewal   = (Get-Date).AddDays(-35)
                        Overdue       = $true
                    }
                )
                Total          = 1
                Valid          = 0
                Overdue        = 1
                RenewedLast24h = 0
            }
        }
        Mock -ModuleName 'TU-ACME' Read-TUACMEKey {
            New-Object System.ConsoleKeyInfo([char]27, [System.ConsoleKey]::Escape, $false, $false, $false)
        }
    }

    It 'renders the report and exits on Escape' {
        { InModuleScope 'TU-ACME' { Show-TUACMERenewalStatus } } | Should -Not -Throw

        Should -Invoke -ModuleName 'TU-ACME' Get-TUACMERenewalStatusData -Times 1 -Exactly
    }

    It 'refreshes on demand (R) before exiting' {
        $script:keys = New-Object System.Collections.Queue
        $script:keys.Enqueue((New-Object System.ConsoleKeyInfo([char]82, [System.ConsoleKey]::R, $false, $false, $false)))
        $script:keys.Enqueue((New-Object System.ConsoleKeyInfo([char]27, [System.ConsoleKey]::Escape, $false, $false, $false)))
        Mock -ModuleName 'TU-ACME' Read-TUACMEKey { $script:keys.Dequeue() }

        InModuleScope 'TU-ACME' { Show-TUACMERenewalStatus }

        Should -Invoke -ModuleName 'TU-ACME' Get-TUACMERenewalStatusData -Times 2 -Exactly
    }

    It 'uses only the locked palette (DarkCyan appears, AC-C.4)' {
        InModuleScope 'TU-ACME' { Show-TUACMERenewalStatus }

        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter {
            [string]$ForegroundColor -eq 'DarkCyan'
        }
    }
}
