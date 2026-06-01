#Requires -Modules Pester

Describe 'UC-9.03 - IIS menu joins bindings to certs by thumbprint' -Tag 'Unit' {
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

    It 'renders the matching cert Subject when certificateHash equals Thumbprint' {
        InModuleScope TU-ACME {
            $script:OnWindows = $true

            $matchHash = 'AABBCCDDEEFF11223344'
            $fakeBindings = @(
                [PSCustomObject]@{
                    ItemXPath          = "/system.applicationHost/sites/site[@name='Site1']"
                    protocol           = 'https'
                    bindingInformation = '*:443:site1.example.com'
                    certificateHash    = $matchHash
                },
                [PSCustomObject]@{
                    ItemXPath          = "/system.applicationHost/sites/site[@name='Site2']"
                    protocol           = 'https'
                    bindingInformation = '*:443:site2.example.com'
                    certificateHash    = 'ZZZZZZZZZZZZZZZZZZZZ'   # no matching cert
                }
            )
            $fakeCerts = @(
                [PSCustomObject]@{
                    Subject    = 'CN=site1.example.com'
                    Thumbprint = $matchHash
                }
            )

            Mock Get-AdminStatus       { $true }
            Mock Use-TUACMEProdAccount {}
            Mock Get-WebBinding        { return $fakeBindings }
            Mock Get-PACertificate     { return $fakeCerts }
            Mock Show-Spinner          { param($Message, $ScriptBlock) & $ScriptBlock }
            Mock Show-Menu             { -1 }
            Mock Invoke-ConsoleClear   {}
            Mock Write-Host            {}
            Mock Read-Host             { '' }

            $script:_capturedRows = $null
            Mock Show-Table {
                param($Data, $Columns, $Headers, $Widths, $ColorRule, $SelectedIndex, [switch]$Interactive)
                $script:_capturedRows = $Data
            }

            Invoke-IISMenu

            $script:_capturedRows         | Should -Not -BeNullOrEmpty
            $script:_capturedRows.Count   | Should -Be 2

            $row1 = $script:_capturedRows | Where-Object { $_.Site -eq 'Site1' } | Select-Object -First 1
            $row1                | Should -Not -BeNullOrEmpty
            $row1.CertSubject    | Should -Be 'CN=site1.example.com'
            $row1.Thumbprint     | Should -Be $matchHash

            $row2 = $script:_capturedRows | Where-Object { $_.Site -eq 'Site2' } | Select-Object -First 1
            $row2                | Should -Not -BeNullOrEmpty
            $row2.CertSubject    | Should -Be '<unknown>'
        }
    }
}
