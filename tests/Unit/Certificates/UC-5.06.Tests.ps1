#Requires -Modules Pester
Describe 'UC-5.06 - Dashboard shows empty-state when no certs' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc506-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'prints No certificates found in yellow and does not call Show-Table' {
        InModuleScope TU-ACME {
            Mock Use-TUACMEProdAccount {}
            Mock Get-PACertificate     { @() }
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
            Mock Show-Table   {}
            Mock Invoke-ConsoleClear {}
            Mock Wait-AnyKey         {}

            Mock Write-Host {}
            Mock Invoke-ConsoleReadKey { New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Escape, $false, $false, $false) }

            Invoke-CertificateDashboard

            Assert-MockCalled Write-Host -ParameterFilter {
                ($Object -match 'No certificates found') -and ($ForegroundColor -eq 'Yellow')
            } -Times 1 -Scope It
            Assert-MockCalled Show-Table -Times 0 -Scope It
        }
    }
}
