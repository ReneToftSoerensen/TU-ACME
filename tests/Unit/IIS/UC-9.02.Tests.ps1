#Requires -Modules Pester

Describe 'UC-9.02 - IIS menu scans every binding (HTTP and HTTPS)' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

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

    It 'calls Get-WebBinding without a Protocol filter so HTTP rows render too' {
        InModuleScope TU-ACME {
            $script:OnWindows = $true

            Mock Get-AdminStatus       { $true }
            Mock Use-TUACMEProdAccount {}
            Mock Get-WebBinding        { return @() }
            Mock Get-PACertificate     { return @() }
            Mock Show-Spinner          { param($Message, $ScriptBlock) & $ScriptBlock }
            Mock Show-Table            {}
            Mock Show-Menu             { -1 }   # immediate Back
            Mock Invoke-ConsoleClear   {}
            Mock Write-Host            {}
            Mock Read-Host             { '' }

            Invoke-IISMenu

            # Operationally the menu has to show every binding so HTTP-
            # only sites are visible alongside HTTPS ones; the -Protocol
            # 'https' filter that the v0.3.x menu had been passing would
            # silently drop them. The assertion guards that regression.
            Assert-MockCalled Get-WebBinding -ParameterFilter {
                -not $PSBoundParameters.ContainsKey('Protocol')
            } -Times 1 -Scope It
        }
    }
}
