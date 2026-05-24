#Requires -Modules Pester
Describe 'UC-5.04 - Dashboard colors certs by expiry' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc504-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'returns Red for expired, Yellow within warn window, Green otherwise' {
        InModuleScope TU-ACME {
            function New-PACertFake {
                param(
                    [string]   $Subject,
                    [datetime] $NotAfter,
                    [string]   $Thumbprint = ('TP' + [guid]::NewGuid().ToString('N').Substring(0,16)),
                    [string]   $FriendlyName = ''
                )
                [PSCustomObject]@{
                    Subject      = $Subject
                    NotAfter     = $NotAfter
                    Thumbprint   = $Thumbprint
                    FriendlyName = $FriendlyName
                }
            }

            $now = Get-Date
            $certs = @(
                (New-PACertFake -Subject 'CN=expired.corp.local' -NotAfter $now.AddDays(-1)),
                (New-PACertFake -Subject 'CN=warn.corp.local'    -NotAfter $now.AddDays(10)),
                (New-PACertFake -Subject 'CN=healthy.corp.local' -NotAfter $now.AddDays(200))
            )

            Mock Use-TUACMEProdAccount {}
            Mock Get-PACertificate     { $certs }
            Mock Get-TUACMEConfig      {
                [PSCustomObject]@{
                    Dashboard = [PSCustomObject]@{
                        WarnDaysThreshold    = 30
                        DefaultSort          = 'ExpiryAscending'
                        ShowDryRunsByDefault = $false
                    }
                }
            }
            Mock Show-Spinner { param($Message, $ScriptBlock) & $ScriptBlock }

            $script:_capturedRule = $null
            $script:_capturedData = $null
            Mock Show-Table {
                param($Data, $Columns, $Headers, $Widths, $ColorRule)
                $script:_capturedRule = $ColorRule
                $script:_capturedData = @($Data)
            }

            Mock Invoke-ConsoleClear {}
            Mock Write-Host          {}
            Mock Wait-AnyKey         {}
            Mock Read-Host           { return 'q' }

            Invoke-CertificateDashboard

            $script:_capturedRule | Should -Not -BeNullOrEmpty

            $expiredRow = $script:_capturedData | Where-Object { $_.Subject -eq 'CN=expired.corp.local' }
            $warnRow    = $script:_capturedData | Where-Object { $_.Subject -eq 'CN=warn.corp.local' }
            $healthyRow = $script:_capturedData | Where-Object { $_.Subject -eq 'CN=healthy.corp.local' }

            (& $script:_capturedRule $expiredRow) | Should -Be 'Red'
            (& $script:_capturedRule $warnRow)    | Should -Be 'Yellow'
            (& $script:_capturedRule $healthyRow) | Should -Be 'Green'
        }
    }
}
