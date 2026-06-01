#Requires -Modules Pester

Describe 'UC-9.04 - IIS rebind invokes Set-WebBinding with new hash' -Tag 'Unit' {
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

    It 'updates the binding certificateHash and writes Event 1002 on success' {
        InModuleScope TU-ACME {
            $script:OnWindows = $true

            $oldHash = '1111111111111111AAAA'
            $newHash = '2222222222222222BBBB'

            $fakeBindings = @(
                [PSCustomObject]@{
                    ItemXPath          = "/system.applicationHost/sites/site[@name='Site1']"
                    protocol           = 'https'
                    bindingInformation = '*:443:site1.example.com'
                    certificateHash    = $oldHash
                }
            )
            $fakeCerts = @(
                [PSCustomObject]@{
                    Subject    = 'CN=site1.example.com'
                    Thumbprint = $newHash
                }
            )

            Mock Get-AdminStatus       { $true }
            Mock Use-TUACMEProdAccount {}
            Mock Get-WebBinding        { return $fakeBindings }
            Mock Get-PACertificate     { return $fakeCerts }
            Mock Show-Spinner          { param($Message, $ScriptBlock) & $ScriptBlock }
            Mock Show-Table            {}
            Mock Invoke-ConsoleClear   {}
            Mock Write-Host            {}
            Mock Set-WebBinding        {}
            Mock Write-EventLogEntry   {}

            # Menu sequence:
            #   1. Outer IIS menu      -> 0 (Rebind a site)
            #   2. Binding picker      -> 0 (the first / only binding)
            #   3. Outer IIS menu      -> 3 (Back; UC-9.11 added an Order entry
            #                            so Back is now index 3 instead of 2)
            $script:_menuCalls = 0
            Mock Show-Menu {
                $script:_menuCalls++
                switch ($script:_menuCalls) {
                    1 { return 0 }   # Rebind
                    2 { return 0 }   # First binding in the picker
                    default { return 3 }   # Back
                }
            }

            # Read-Host sequence: cert number, then "press Enter".
            $script:_readCalls = 0
            Mock Read-Host {
                $script:_readCalls++
                switch ($script:_readCalls) {
                    1 { return '1' }
                    default { return '' }
                }
            }

            Invoke-IISMenu

            Assert-MockCalled Set-WebBinding -ParameterFilter {
                $PropertyName -eq 'certificateHash' -and $Value -eq $newHash
            } -Times 1 -Scope It

            Assert-MockCalled Write-EventLogEntry -ParameterFilter {
                $EventId -eq 1002
            } -Times 1 -Scope It
        }
    }
}
