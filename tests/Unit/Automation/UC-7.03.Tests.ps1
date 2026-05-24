#Requires -Modules Pester

Describe 'UC-7.03 - Send-Test emits Event 1007 on success' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc703-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'calls Send-TUACMEMail once and writes Event 1007 on success when option 2 is selected' {
        InModuleScope TU-ACME {
            Mock Send-TUACMEMail     { $true }
            Mock Write-EventLogEntry {}
            Mock Invoke-ConsoleClear {}
            Mock Read-Host           { '' }

            # Show-Menu: first call -> 1 (Send test mail), second call -> -1 (exit loop)
            $script:_menuCalls = 0
            Mock Show-Menu {
                $i = $script:_menuCalls
                $script:_menuCalls = $i + 1
                if ($i -eq 0) { return 1 } else { return -1 }
            }

            Invoke-SMTPConfig

            Assert-MockCalled Send-TUACMEMail -Times 1 -Scope It -ParameterFilter {
                $Subject -eq 'TU-ACME test mail'
            }
            Assert-MockCalled Write-EventLogEntry -Times 1 -Scope It -ParameterFilter {
                $EventId -eq 1007
            }
        }
    }
}
