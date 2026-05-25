#Requires -Modules Pester
Describe 'UC-5.05 - Dashboard respects DefaultSort config' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc505-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'sorts rows by NotAfter descending when DefaultSort is ExpiryDescending' {
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
                (New-PACertFake -Subject 'CN=mid.corp.local'  -NotAfter $now.AddDays(30)),
                (New-PACertFake -Subject 'CN=near.corp.local' -NotAfter $now.AddDays(10)),
                (New-PACertFake -Subject 'CN=far.corp.local'  -NotAfter $now.AddDays(90))
            )

            Mock Use-TUACMEProdAccount {}
            Mock Get-PACertificate     { $certs }
            Mock Get-TUACMEConfig      {
                [PSCustomObject]@{
                    Dashboard = [PSCustomObject]@{
                        WarnDaysThreshold    = 30
                        DefaultSort          = 'ExpiryDescending'
                        ShowDryRunsByDefault = $false
                    }
                }
            }
            Mock Show-Spinner { param($Message, $ScriptBlock) & $ScriptBlock }

            $script:_capturedData = $null
            Mock Show-Table {
                param($Data, $Columns, $Headers, $Widths, $ColorRule)
                $script:_capturedData = @($Data)
            }

            Mock Invoke-ConsoleClear {}
            Mock Write-Host          {}
            Mock Wait-AnyKey         {}
            Mock Invoke-ConsoleReadKey { New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Escape, $false, $false, $false) }

            Invoke-CertificateDashboard

            $script:_capturedData.Count | Should -Be 3
            $script:_capturedData[0].Subject | Should -Be 'CN=far.corp.local'
            $script:_capturedData[1].Subject | Should -Be 'CN=mid.corp.local'
            $script:_capturedData[2].Subject | Should -Be 'CN=near.corp.local'
        }
    }
}
