#Requires -Modules Pester
Describe 'UC-5.07 - Dashboard e hotkey opens Export menu' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc507-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'calls Invoke-ExportMenu when the operator presses e' {
        InModuleScope TU-ACME {
            # Define Invoke-ExportMenu inside the module session so the
            # runtime Get-Command lookup in Invoke-CertificateDashboard
            # resolves it and Mock has something to intercept.
            function Invoke-ExportMenu { }

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
            Mock Show-Table          {}
            Mock Invoke-ConsoleClear {}
            Mock Write-Host          {}
            Mock Wait-AnyKey         {}
            Mock Invoke-ExportMenu   {}

            $script:_ans = @('e', 'q')
            $script:_idx = 0
            Mock Read-Host {
                $i = $script:_idx
                $script:_idx = $i + 1
                if ($i -ge $script:_ans.Count) { return 'q' }
                return $script:_ans[$i]
            }

            Invoke-CertificateDashboard

            Assert-MockCalled Invoke-ExportMenu -Times 1 -Scope It
        }
    }
}
