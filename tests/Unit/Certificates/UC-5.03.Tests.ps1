#Requires -Modules Pester
Describe 'UC-5.03 - Dashboard d hotkey reveals dry-runs pane' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc503-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'renders a second Show-Table for dry-runs after d is pressed' {
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
                (New-PACertFake -Subject 'CN=prod.corp.local'   -NotAfter $now.AddDays(60)),
                (New-PACertFake -Subject 'CN=dryrun.corp.local' -NotAfter $now.AddDays(5)  -FriendlyName 'TU-ACME-DryRun')
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

            # Send 'd' once to toggle dry-runs, then Escape to exit.
            $script:_keys = @(
                (New-Object System.ConsoleKeyInfo([char]'d', [System.ConsoleKey]::D,      $false, $false, $false)),
                (New-Object System.ConsoleKeyInfo([char]0,   [System.ConsoleKey]::Escape, $false, $false, $false))
            )
            $script:_idx = 0
            Mock Invoke-ConsoleReadKey {
                $i = $script:_idx
                $script:_idx = $i + 1
                if ($i -ge $script:_keys.Count) { return $script:_keys[$script:_keys.Count - 1] }
                return $script:_keys[$i]
            }

            Invoke-CertificateDashboard

            # First iteration: only prod table.
            # Second iteration (after 'd'): prod + dry-run table. Total = 3 Show-Table calls.
            $script:_tableCalls.Count | Should -Be 3

            # Last call should be the dry-run pane.
            $lastData = $script:_tableCalls[$script:_tableCalls.Count - 1]
            $lastData.Count | Should -Be 1
            $lastData[0].FriendlyName | Should -Be 'TU-ACME-DryRun'
        }
    }
}
