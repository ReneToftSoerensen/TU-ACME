#Requires -Modules Pester

Describe 'UC-9.01 - IIS menu calls Use-TUACMEProdAccount first' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        # Get-WebBinding / Set-WebBinding / Import-Module (with -Force) are
        # Windows-only in the WebAdministration sense. Inject stubs so Mock
        # has something to bind on Linux pwsh CI runners.
        if (-not (Get-Command Get-WebBinding -ErrorAction SilentlyContinue)) {
            & (Get-Module TU-ACME) {
                function script:Get-WebBinding { param($Protocol) }
                function script:Set-WebBinding { param($Name,$BindingInformation,$PropertyName,$Value) }
                function script:Import-Module  { param($Name,[switch]$Force,[string]$ErrorAction='Continue') }
            }
        }
    }
    AfterAll {
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'invokes Use-TUACMEProdAccount before Get-WebBinding and Get-PACertificate' {
        InModuleScope TU-ACME {
            $script:OnWindows = $true
            $script:_callOrder = New-Object System.Collections.ArrayList

            Mock Get-AdminStatus       { $true }
            Mock Use-TUACMEProdAccount { [void]$script:_callOrder.Add('Use-TUACMEProdAccount') }
            Mock Get-WebBinding        { [void]$script:_callOrder.Add('Get-WebBinding'); return @() }
            Mock Get-PACertificate     { [void]$script:_callOrder.Add('Get-PACertificate'); return @() }
            Mock Show-Spinner          { param($Message, $ScriptBlock) & $ScriptBlock }
            Mock Show-Table            {}
            Mock Show-Menu             { -1 }   # immediate Back
            Mock Invoke-ConsoleClear   {}
            Mock Write-Host            {}
            Mock Read-Host             { '' }

            Invoke-IISMenu

            Assert-MockCalled Use-TUACMEProdAccount -Times 1 -Scope It
            $script:_callOrder[0] | Should -Be 'Use-TUACMEProdAccount'
            ([Array]::IndexOf($script:_callOrder.ToArray(), 'Use-TUACMEProdAccount')) |
                Should -BeLessThan ([Array]::IndexOf($script:_callOrder.ToArray(), 'Get-WebBinding'))
            ([Array]::IndexOf($script:_callOrder.ToArray(), 'Use-TUACMEProdAccount')) |
                Should -BeLessThan ([Array]::IndexOf($script:_callOrder.ToArray(), 'Get-PACertificate'))
        }
    }
}
