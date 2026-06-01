#Requires -Modules Pester

Describe 'UC-9.07/08/09 - IIS table lists HTTP+HTTPS, shows Expires and Template' -Tag 'Unit' {
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

    It 'UC-9.07: renders one row per binding across HTTP and HTTPS protocols' {
        InModuleScope TU-ACME {
            $script:OnWindows = $true

            $fakeBindings = @(
                [PSCustomObject]@{
                    ItemXPath          = "/system.applicationHost/sites/site[@name='Site1']"
                    protocol           = 'https'
                    bindingInformation = '*:443:site1.example.com'
                    certificateHash    = 'HTTPS1'
                },
                [PSCustomObject]@{
                    ItemXPath          = "/system.applicationHost/sites/site[@name='Site1']"
                    protocol           = 'http'
                    bindingInformation = '*:80:site1.example.com'
                    certificateHash    = ''
                },
                [PSCustomObject]@{
                    ItemXPath          = "/system.applicationHost/sites/site[@name='Site3-HttpOnly']"
                    protocol           = 'http'
                    bindingInformation = '*:80:'
                    certificateHash    = ''
                }
            )

            Mock Get-AdminStatus       { $true }
            Mock Use-TUACMEProdAccount {}
            Mock Get-WebBinding        { return $fakeBindings }
            Mock Get-PACertificate     { @() }
            Mock Show-Spinner          { param($Message, $ScriptBlock) & $ScriptBlock }
            Mock Test-Path             { $false }
            Mock Show-Menu             { -1 }
            Mock Invoke-ConsoleClear   {}
            Mock Write-Host            {}
            Mock Read-Host             { '' }

            $script:_capturedRows    = $null
            $script:_capturedColumns = $null
            Mock Show-Table {
                param($Data, $Columns, $Headers, $Widths, $ColorRule, $SelectedIndex, [switch]$Interactive)
                $script:_capturedRows    = $Data
                $script:_capturedColumns = $Columns
            }

            Invoke-IISMenu

            $script:_capturedRows.Count | Should -Be 3

            $http  = @($script:_capturedRows | Where-Object { $_.Protocol -eq 'http' })
            $https = @($script:_capturedRows | Where-Object { $_.Protocol -eq 'https' })
            $http.Count  | Should -Be 2
            $https.Count | Should -Be 1

            # New columns must be in the render order so the table layout
            # explicitly carries Protocol, Expires, Template.
            $script:_capturedColumns | Should -Contain 'Protocol'
            $script:_capturedColumns | Should -Contain 'Expires'
            $script:_capturedColumns | Should -Contain 'Template'
        }
    }

    It 'UC-9.08: HTTPS row carries the NotAfter date from the LocalMachine\My cert' {
        InModuleScope TU-ACME {
            $script:OnWindows = $true

            $fakeBindings = @(
                [PSCustomObject]@{
                    ItemXPath          = "/system.applicationHost/sites/site[@name='Site1']"
                    protocol           = 'https'
                    bindingInformation = '*:443:site1.example.com'
                    certificateHash    = 'HASH1'
                }
            )
            # Hand-built fake X509Certificate2 shape: Test-Path returns
            # $true for the per-thumbprint path, Get-Item returns this.
            # NotAfter intentionally past today's date in the future.
            $fakeCert = [PSCustomObject]@{
                Subject    = 'CN=site1.example.com'
                NotAfter   = (Get-Date '2027-04-15')
                Extensions = @()
            }

            Mock Get-AdminStatus       { $true }
            Mock Use-TUACMEProdAccount {}
            Mock Get-WebBinding        { return $fakeBindings }
            Mock Get-PACertificate     { @() }
            Mock Show-Spinner          { param($Message, $ScriptBlock) & $ScriptBlock }
            Mock Test-Path             { param($Path) $Path -like '*HASH1*' }
            Mock Get-Item              { return $fakeCert }
            Mock Show-Menu             { -1 }
            Mock Invoke-ConsoleClear   {}
            Mock Write-Host            {}
            Mock Read-Host             { '' }

            $script:_rows = $null
            Mock Show-Table {
                param($Data, $Columns, $Headers, $Widths, $ColorRule, $SelectedIndex, [switch]$Interactive)
                $script:_rows = $Data
            }

            Invoke-IISMenu

            $row = $script:_rows | Select-Object -First 1
            $row.Expires | Should -Be '2027-04-15'
        }
    }

    It 'UC-9.09: HTTPS row carries the AD CS template name from cert extensions' {
        InModuleScope TU-ACME {
            $script:OnWindows = $true

            $fakeBindings = @(
                [PSCustomObject]@{
                    ItemXPath          = "/system.applicationHost/sites/site[@name='Site1']"
                    protocol           = 'https'
                    bindingInformation = '*:443:site1.example.com'
                    certificateHash    = 'HASH1'
                }
            )
            $fakeCert = [PSCustomObject]@{
                Subject    = 'CN=site1.example.com'
                NotAfter   = (Get-Date '2027-04-15')
                Extensions = @()
            }

            Mock Get-AdminStatus       { $true }
            Mock Use-TUACMEProdAccount {}
            Mock Get-WebBinding        { return $fakeBindings }
            Mock Get-PACertificate     { @() }
            Mock Show-Spinner          { param($Message, $ScriptBlock) & $ScriptBlock }
            Mock Test-Path             { param($Path) $Path -like '*HASH1*' }
            Mock Get-Item              { return $fakeCert }
            Mock Get-CertTemplateName  { return 'WebServer-Custom' }
            Mock Show-Menu             { -1 }
            Mock Invoke-ConsoleClear   {}
            Mock Write-Host            {}
            Mock Read-Host             { '' }

            $script:_rows = $null
            Mock Show-Table {
                param($Data, $Columns, $Headers, $Widths, $ColorRule, $SelectedIndex, [switch]$Interactive)
                $script:_rows = $Data
            }

            Invoke-IISMenu

            $row = $script:_rows | Select-Object -First 1
            $row.Template | Should -Be 'WebServer-Custom'

            # The menu must reach into the helper for HTTPS rows that
            # have a resolvable Cert:\LocalMachine\My item, otherwise
            # any future refactor that drops the call site (e.g. moves
            # template extraction elsewhere) silently regresses this UC.
            Assert-MockCalled Get-CertTemplateName -Times 1 -Scope It
        }
    }
}
