#Requires -Modules Pester

Describe 'UC-11.02 - Log viewer export prompts before overwriting' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force
    }
    AfterAll {
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'does not call Export-Csv when the operator declines overwriting an existing file' {
        InModuleScope TU-ACME {
            $script:OnWindows = $true

            $fakeEvents = @(
                [PSCustomObject]@{
                    TimeCreated      = (Get-Date)
                    Id               = 1010
                    LevelDisplayName = 'Information'
                    Message          = 'init'
                }
            )

            Mock Get-WinEvent      { $fakeEvents }
            Mock Show-Table        {}
            Mock Invoke-ConsoleClear {}
            Mock Export-Csv        {}
            Mock Test-Path         { $true }

            # First Show-Menu call selects "Export to file" (index 1),
            # second call returns -1 to exit the loop.
            $script:_menuCalls = 0
            Mock Show-Menu {
                $i = $script:_menuCalls
                $script:_menuCalls = $i + 1
                if ($i -eq 0) { return 1 } else { return -1 }
            }

            # Read-Host: 1st call = path, 2nd call = overwrite prompt -> 'n'
            $script:_rhCalls = 0
            Mock Read-Host {
                $i = $script:_rhCalls
                $script:_rhCalls = $i + 1
                if ($i -eq 0) { return 'C:\Temp\tuacme-events.csv' }
                return 'n'
            }

            Invoke-LogViewer

            Assert-MockCalled Export-Csv -Times 0 -Scope It
            Assert-MockCalled Test-Path  -Times 1 -Scope It
        }
    }
}
