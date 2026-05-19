#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"
. "$PSScriptRoot\..\..\Fixtures\FakeObjects.ps1"

BeforeDiscovery { Import-TUACMEModule }

Describe 'Invoke-IISMenu' -Tag Unit, IIS {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        BeforeEach {
            $script:TUACMEIsAdmin = $true
            Mock -CommandName 'Write-Host'            -MockWith {}
            Mock -CommandName 'Invoke-ConsoleClear'   -MockWith {}
            Mock -CommandName 'Invoke-ConsoleWaitKey' -MockWith {}
            Mock -CommandName 'Import-Module'         -MockWith {}
            Mock -CommandName 'Show-Menu'             -MockWith { -1 }
            Mock -CommandName 'Show-StatusBar'        -MockWith {}
            Mock -CommandName 'Get-WebBinding'        -MockWith { @(New-FakeIISBinding) }
            Mock -CommandName 'Get-PACertificate'     -MockWith { @(New-FakeCertificate) }
            Mock -CommandName 'Set-WebBinding'        -MockWith {}
            Mock -CommandName 'Import-PfxCertificate' -MockWith {}
            Mock -CommandName 'Set-PAConfig'          -MockWith {}
            Mock -CommandName 'Write-EventLogEntry'   -MockWith {}
        }

        Context 'Not admin — returns early without loading IIS' {
            BeforeEach {
                $script:TUACMEIsAdmin = $false
                Mock -CommandName 'Start-Sleep' -MockWith {}
            }
            It 'does not call Import-Module WebAdministration' {
                Invoke-IISMenu
                Should -Invoke Import-Module -Times 0
            }
        }

        Context 'WebAdministration import fails — shows error and returns' {
            BeforeEach {
                Mock -CommandName 'Import-Module' -MockWith { throw 'Module not found' }
            }
            It 'does not throw' {
                { Invoke-IISMenu } | Should -Not -Throw
            }
        }

        Context '_Show-IISBindings — no bindings' {
            BeforeEach {
                Mock -CommandName 'Get-WebBinding'    -MockWith { @() }
                Mock -CommandName 'Show-Table'        -MockWith {}
            }
            It 'does not call Show-Table' {
                _Show-IISBindings
                Should -Invoke Show-Table -Times 0
            }
        }

        Context '_Show-IISBindings — bindings exist, Posh-ACME certs matched' {
            BeforeEach {
                Mock -CommandName 'Show-Table' -MockWith {}
            }
            It 'calls Show-Table once' {
                _Show-IISBindings
                Should -Invoke Show-Table -Times 1 -Exactly
            }
        }

        Context '_Register-PostRenewalPlugin — script not found' {
            BeforeEach {
                Mock -CommandName 'Test-Path' -MockWith { $false }
            }
            It 'does not call Set-PAConfig' {
                _Register-PostRenewalPlugin
                Should -Invoke Set-PAConfig -Times 0
            }
        }

        Context '_Register-PostRenewalPlugin — script found, user confirms' {
            BeforeEach {
                Mock -CommandName 'Test-Path' -MockWith { $true }
                Mock -CommandName 'Get-PAServer' -MockWith { [PSCustomObject]@{ PostScript = '' } }
                Mock -CommandName 'Read-Host'   -MockWith { 'J' }
            }
            It 'calls Set-PAConfig once' {
                _Register-PostRenewalPlugin
                Should -Invoke Set-PAConfig -Times 1 -Exactly
            }
        }

        Context '_Bind-CertToIIS — no certs available' {
            BeforeEach {
                Mock -CommandName 'Get-PACertificate' -MockWith { @() }
                Mock -CommandName 'Start-Sleep'       -MockWith {}
            }
            It 'does not call Set-WebBinding' {
                _Bind-CertToIIS
                Should -Invoke Set-WebBinding -Times 0
            }
        }
    }
}
