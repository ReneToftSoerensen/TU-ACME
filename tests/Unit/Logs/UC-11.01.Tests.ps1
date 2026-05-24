#Requires -Modules Pester

Describe 'UC-11.01 - Log viewer reads TU-ACME provider events' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force
    }
    AfterAll {
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'queries Get-WinEvent once with ProviderName TU-ACME and MaxEvents 50' {
        InModuleScope TU-ACME {
            $script:OnWindows = $true

            $fakeEvents = @(
                [PSCustomObject]@{
                    TimeCreated      = (Get-Date)
                    Id               = 1010
                    LevelDisplayName = 'Information'
                    Message          = 'init'
                },
                [PSCustomObject]@{
                    TimeCreated      = (Get-Date)
                    Id               = 1001
                    LevelDisplayName = 'Information'
                    Message          = 'renewal'
                }
            )

            Mock Get-WinEvent      { $fakeEvents }
            Mock Show-Table        {}
            Mock Show-Menu         { -1 }   # immediate Back
            Mock Read-Host         { '' }
            Mock Invoke-ConsoleClear {}

            Invoke-LogViewer

            Assert-MockCalled Get-WinEvent -ParameterFilter {
                $FilterHashtable.ProviderName -eq 'TU-ACME' -and $MaxEvents -eq 50
            } -Times 1 -Scope It

            Assert-MockCalled Show-Table -Times 1 -Scope It
        }
    }
}
