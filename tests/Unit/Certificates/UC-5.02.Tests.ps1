#Requires -Modules Pester
Describe 'UC-5.02 - Dashboard hides dry-run certs by default' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc502-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'omits TU-ACME-DryRun entries from the rendered table when ShowDryRunsByDefault is $false' {
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
                (New-PACertFake -Subject 'CN=prod1.corp.local'   -NotAfter $now.AddDays(60)),
                (New-PACertFake -Subject 'CN=dryrun.corp.local' -NotAfter $now.AddDays(2)  -FriendlyName 'TU-ACME-DryRun'),
                (New-PACertFake -Subject 'CN=prod2.corp.local'   -NotAfter $now.AddDays(15))
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

            $script:_tableCalls = New-Object System.Collections.ArrayList
            Mock Show-Table { param($Data, $Columns, $Headers, $Widths, $ColorRule)
                [void]$script:_tableCalls.Add(@($Data))
            }

            Mock Invoke-ConsoleClear {}
            Mock Write-Host          {}
            Mock Wait-AnyKey         {}
            Mock Read-Host           { return 'q' }

            Invoke-CertificateDashboard

            $script:_tableCalls.Count | Should -Be 1
            $first = $script:_tableCalls[0]
            $first.Count | Should -Be 2
            ($first | Where-Object { $_.FriendlyName -eq 'TU-ACME-DryRun' }).Count | Should -Be 0
            ($first | ForEach-Object { $_.Subject }) | Should -Contain 'CN=prod1.corp.local'
            ($first | ForEach-Object { $_.Subject }) | Should -Contain 'CN=prod2.corp.local'
        }
    }
}
