#Requires -Modules Pester

Describe 'UC-9.02 - IIS menu scans HTTPS bindings' -Tag 'Unit' {
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

    It 'calls Get-WebBinding -Protocol https exactly once per render pass' {
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

            Assert-MockCalled Get-WebBinding -ParameterFilter {
                $Protocol -eq 'https'
            } -Times 1 -Scope It
        }
    }
}
