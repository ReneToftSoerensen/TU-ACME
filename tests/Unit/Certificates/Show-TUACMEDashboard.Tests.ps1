BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')

    function script:New-EscapeKey {
        New-Object System.ConsoleKeyInfo([char]27, [System.ConsoleKey]::Escape, $false, $false, $false)
    }
    function script:New-DownKey {
        New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::DownArrow, $false, $false, $false)
    }
}

Describe 'Get-TUACMEDashboardData (UC-12.01 / AC-J.1)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISBinding { @() }
        Mock -ModuleName 'TU-ACME' Get-TUACMECertificate {
            @(
                [pscustomobject]@{ MainDomain = 'later.example.com'; Thumbprint = 'CCC'; NotAfter = (Get-Date).AddDays(80) },
                [pscustomobject]@{ MainDomain = 'soon.example.com'; Thumbprint = 'BBB'; NotAfter = (Get-Date).AddDays(10) },
                [pscustomobject]@{ MainDomain = 'expired.example.com'; Thumbprint = 'AAA'; NotAfter = (Get-Date).AddDays(-5) }
            )
        }
    }

    It 'sorts rows by expiry date, soonest first' {
        $data = InModuleScope 'TU-ACME' { Get-TUACMEDashboardData }

        $data.Rows[0].Domain | Should -Be 'expired.example.com'
        $data.Rows[1].Domain | Should -Be 'soon.example.com'
        $data.Rows[2].Domain | Should -Be 'later.example.com'
    }

    It 'marks certificates within 30 days as Renew Soon and expired ones as Expired' {
        $data = InModuleScope 'TU-ACME' { Get-TUACMEDashboardData }

        $data.Rows[0].Status | Should -Be 'Expired'
        $data.Rows[1].Status | Should -Be 'Renew Soon'
        $data.Rows[2].Status | Should -Be ''
    }

    It 'reports total, valid, renew-soon, and expired counts' {
        $data = InModuleScope 'TU-ACME' { Get-TUACMEDashboardData }

        $data.Total | Should -Be 3
        $data.Valid | Should -Be 2
        $data.RenewSoon | Should -Be 1
        $data.Expired | Should -Be 1
    }

    It 'leaves the status blank when the expiry date is unknown' {
        # $null NotAfter compares as less-than any date; it must not be
        # presented as Expired.
        Mock -ModuleName 'TU-ACME' Get-TUACMECertificate {
            @([pscustomobject]@{ MainDomain = 'odd.example.com'; Thumbprint = 'DDD'; NotAfter = $null })
        }

        $data = InModuleScope 'TU-ACME' { Get-TUACMEDashboardData }

        $data.Rows[0].Status | Should -Be ''
        $data.Expired | Should -Be 0
    }

    It 'joins IIS bindings to certificates by thumbprint' {
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISBinding {
            @([pscustomobject]@{
                    SiteName           = 'Default Web Site'
                    Protocol           = 'https'
                    BindingInformation = '*:443:soon.example.com'
                    HostHeader         = 'soon.example.com'
                    Thumbprint         = 'BBB'
                    NotAfter           = $null
                    Template           = ''
                })
        }

        $data = InModuleScope 'TU-ACME' { Get-TUACMEDashboardData }

        $bound = @($data.Rows | Where-Object { $_.Thumbprint -eq 'BBB' })[0]
        $bound.IISBindings | Should -Be 'Default Web Site (*:443:soon.example.com)'
        $unbound = @($data.Rows | Where-Object { $_.Thumbprint -eq 'CCC' })[0]
        $unbound.IISBindings | Should -Be ''
    }
}

Describe 'Show-TUACMEDashboard (UC-12.01 / AC-J.1, AC-C.4)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Write-Host { }
        Mock -ModuleName 'TU-ACME' Clear-Host { }
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISBinding { @() }
        Mock -ModuleName 'TU-ACME' Get-TUACMECertificate {
            @(
                [pscustomobject]@{ MainDomain = 'a.example.com'; Thumbprint = 'AAA'; NotAfter = (Get-Date).AddDays(60) },
                [pscustomobject]@{ MainDomain = 'b.example.com'; Thumbprint = 'BBB'; NotAfter = (Get-Date).AddDays(70) }
            )
        }
        Mock -ModuleName 'TU-ACME' Read-TUACMEKey { New-EscapeKey }
    }

    It 'renders every certificate row and a summary, then closes on Escape' {
        InModuleScope 'TU-ACME' { Show-TUACMEDashboard }

        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter { $Object -like '*a.example.com*' }
        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter { $Object -like '*b.example.com*' }
        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter { $Object -like 'Total: 2*' }
        Should -Invoke -ModuleName 'TU-ACME' Read-TUACMEKey -Times 1 -Exactly
    }

    It 'uses only Cyan and DarkCyan' {
        InModuleScope 'TU-ACME' { Show-TUACMEDashboard }

        Should -Invoke -ModuleName 'TU-ACME' Write-Host -Times 0 -Exactly -ParameterFilter {
            $null -ne $ForegroundColor -and @('Cyan', 'DarkCyan') -notcontains [string]$ForegroundColor
        }
    }

    It 'scrolls down one row per DownArrow when rows exceed the page' {
        $script:keyQueue = New-Object System.Collections.Queue
        $script:keyQueue.Enqueue((New-DownKey))
        $script:keyQueue.Enqueue((New-EscapeKey))
        Mock -ModuleName 'TU-ACME' Read-TUACMEKey { $script:keyQueue.Dequeue() }

        InModuleScope 'TU-ACME' { Show-TUACMEDashboard -PageSize 1 }

        # Two renders: initial page, then the page after scrolling.
        Should -Invoke -ModuleName 'TU-ACME' Clear-Host -Times 2 -Exactly
        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter { $Object -like '*b.example.com*' }
    }

    It 'shows an empty-store hint when no certificates exist' {
        Mock -ModuleName 'TU-ACME' Get-TUACMECertificate { @() }

        InModuleScope 'TU-ACME' { Show-TUACMEDashboard }

        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter { $Object -like 'No certificates*' }
    }

    It 'lists every IIS binding with its certificate details (AC-G.1)' {
        Mock -ModuleName 'TU-ACME' Get-TUACMEIISBinding {
            @(
                [pscustomobject]@{
                    SiteName           = 'Default Web Site'
                    Protocol           = 'https'
                    BindingInformation = '*:443:www.example.com'
                    HostHeader         = 'www.example.com'
                    Thumbprint         = 'NOT-IN-STORE'
                    NotAfter           = (Get-Date).AddDays(42)
                    Template           = 'WebServerV2'
                },
                [pscustomobject]@{
                    SiteName           = 'Default Web Site'
                    Protocol           = 'http'
                    BindingInformation = '*:80:'
                    HostHeader         = ''
                    Thumbprint         = ''
                    NotAfter           = $null
                    Template           = ''
                }
            )
        }

        InModuleScope 'TU-ACME' { Show-TUACMEDashboard }

        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter {
            $Object -like '*www.example.com*NOT-IN-STORE*WebServerV2*'
        }
        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter {
            $Object -like '*http *'
        }
    }
}
