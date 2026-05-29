#Requires -Modules Pester

Describe 'UC-9.06 - IIS rebind picker lists sites with their hostnames' -Tag 'Unit' {
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

    It 'invokes Show-Menu with one entry per binding labeled "Site - hostname"' {
        InModuleScope TU-ACME {
            $script:OnWindows = $true

            # Three bindings across two sites:
            #   * Default Web Site - example.com
            #   * Default Web Site - www.example.com
            #   * Intranet         - (no hostname / catch-all)
            $fakeBindings = @(
                [PSCustomObject]@{
                    ItemXPath          = "/system.applicationHost/sites/site[@name='Default Web Site']"
                    bindingInformation = '*:443:example.com'
                    certificateHash    = 'AAA'
                },
                [PSCustomObject]@{
                    ItemXPath          = "/system.applicationHost/sites/site[@name='Default Web Site']"
                    bindingInformation = '*:443:www.example.com'
                    certificateHash    = 'AAA'
                },
                [PSCustomObject]@{
                    ItemXPath          = "/system.applicationHost/sites/site[@name='Intranet']"
                    bindingInformation = '*:443:'
                    certificateHash    = 'BBB'
                }
            )

            Mock Get-AdminStatus       { $true }
            Mock Use-TUACMEProdAccount {}
            Mock Get-WebBinding        { return $fakeBindings }
            Mock Get-PACertificate     { @() }
            Mock Show-Spinner          { param($Message, $ScriptBlock) & $ScriptBlock }
            Mock Show-Table            {}
            Mock Invoke-ConsoleClear   {}
            Mock Write-Host            {}
            Mock Set-WebBinding        {}
            Mock Write-EventLogEntry   {}

            # Capture every Show-Menu call so the test can assert on the
            # picker invocation specifically.
            $script:_menuCalls   = 0
            $script:_pickerOpts  = $null
            $script:_pickerTitle = $null
            $script:_pickerAllowSearch = $false
            Mock Show-Menu {
                param($Title, $Options, $InitialIndex, $StatusMessage, $DisabledIndices, [switch]$AllowSearch)
                $script:_menuCalls++
                if ($script:_menuCalls -eq 1) { return 0 }   # Rebind
                if ($script:_menuCalls -eq 2) {
                    $script:_pickerTitle       = $Title
                    $script:_pickerOpts        = $Options
                    $script:_pickerAllowSearch = [bool]$AllowSearch
                    # Return the picker's last index (Back) so the rebind
                    # branch short-circuits without continuing into the
                    # cert picker.
                    return ($Options.Count - 1)
                }
                return 2   # Outer Back
            }

            Mock Read-Host { '' }

            Invoke-IISMenu

            $script:_pickerTitle | Should -Be 'TU-ACME - Pick a binding to rebind'
            $script:_pickerAllowSearch | Should -BeTrue
            $script:_pickerOpts.Count | Should -Be 4   # 3 bindings + Back

            $script:_pickerOpts[0] | Should -Be '1. Default Web Site - example.com'
            $script:_pickerOpts[1] | Should -Be '2. Default Web Site - www.example.com'
            $script:_pickerOpts[2] | Should -Be '3. Intranet - <no hostname>'
            $script:_pickerOpts[3] | Should -Be 'B. Back'
        }
    }
}
