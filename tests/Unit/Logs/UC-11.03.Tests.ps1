#Requires -Modules Pester

Describe 'UC-11.03 - Log viewer is a no-op on non-Windows' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force
        if (-not (Get-Command Get-WinEvent -ErrorAction SilentlyContinue)) {
            & (Get-Module TU-ACME) { function script:Get-WinEvent { param([hashtable]$FilterHashtable,[int]$MaxEvents) } }
        }
    }
    AfterAll {
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'does not call Get-WinEvent and prints the unsupported-platform message when OnWindows is false' {
        InModuleScope TU-ACME {
            $script:OnWindows = $false

            Mock Get-WinEvent      {}
            Mock Show-Table        {}
            Mock Show-Menu         {}
            Mock Read-Host         {}
            Mock Invoke-ConsoleClear {}

            Invoke-LogViewer

            Assert-MockCalled Get-WinEvent -Times 0 -Scope It
            Assert-MockCalled Show-Menu    -Times 0 -Scope It
        }
    }
}
