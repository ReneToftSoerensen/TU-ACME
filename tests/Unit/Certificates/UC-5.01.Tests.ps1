#Requires -Modules Pester
Describe 'UC-5.01 - Dashboard calls Use-TUACMEProdAccount first' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc501-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'invokes Use-TUACMEProdAccount before Get-PACertificate' {
        InModuleScope TU-ACME {
            $script:_callOrder = New-Object System.Collections.ArrayList

            Mock Use-TUACMEProdAccount { [void]$script:_callOrder.Add('Use-TUACMEProdAccount') }
            Mock Get-PACertificate     { [void]$script:_callOrder.Add('Get-PACertificate'); return @() }
            Mock Get-TUACMEConfig      {
                [PSCustomObject]@{
                    Dashboard = [PSCustomObject]@{
                        WarnDaysThreshold    = 30
                        DefaultSort          = 'ExpiryAscending'
                        ShowDryRunsByDefault = $false
                    }
                }
            }
            Mock Show-Spinner        { param($Message, $ScriptBlock) & $ScriptBlock }
            Mock Show-Table          {}
            Mock Invoke-ConsoleClear {}
            Mock Write-Host          {}
            Mock Wait-AnyKey         {}
            Mock Invoke-ConsoleReadKey { New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Escape, $false, $false, $false) }

            Invoke-CertificateDashboard

            Assert-MockCalled Use-TUACMEProdAccount -Times 1 -Scope It
            $script:_callOrder[0] | Should -Be 'Use-TUACMEProdAccount'
            $script:_callOrder    | Should -Contain 'Get-PACertificate'
            ([Array]::IndexOf($script:_callOrder.ToArray(), 'Use-TUACMEProdAccount')) |
                Should -BeLessThan ([Array]::IndexOf($script:_callOrder.ToArray(), 'Get-PACertificate'))
        }
    }
}
