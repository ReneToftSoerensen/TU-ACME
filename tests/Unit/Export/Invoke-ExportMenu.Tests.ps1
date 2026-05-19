#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"
. "$PSScriptRoot\..\..\Fixtures\FakeObjects.ps1"

BeforeDiscovery { Import-TUACMEModule }

Describe 'Invoke-ExportMenu' -Tag Unit, Export {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        BeforeEach {
            Mock -CommandName 'Write-Host'            -MockWith {}
            Mock -CommandName 'Invoke-ConsoleClear'   -MockWith {}
            Mock -CommandName 'Invoke-ConsoleWaitKey' -MockWith {}
            Mock -CommandName 'Show-Menu'             -MockWith { -1 }   # ESC exits
            Mock -CommandName 'Get-PACertificate'     -MockWith { @(New-FakeCertificate) }
        }

        Context 'Cert passed directly — skips selection menu' {
            It 'does not call Get-PACertificate' {
                Invoke-ExportMenu -Cert (New-FakeCertificate)
                Should -Invoke Get-PACertificate -Times 0
            }
        }

        Context 'No cert passed — prompts selection' {
            It 'calls Get-PACertificate' {
                Invoke-ExportMenu
                Should -Invoke Get-PACertificate -Times 1 -Exactly
            }
        }

        Context 'No certs available — returns early' {
            BeforeEach {
                Mock -CommandName 'Get-PACertificate' -MockWith { @() }
                Mock -CommandName 'Start-Sleep' -MockWith {}
            }
            It 'does not call Show-Menu for sub-menu' {
                Invoke-ExportMenu
                Should -Invoke Show-Menu -Times 0
            }
        }

        Context '_Export-PEM — copies three files' {
            BeforeEach {
                $script:cert = New-FakeCertificate
                Mock -CommandName 'Read-Host'   -MockWith { 'C:\Temp' }
                Mock -CommandName 'Test-Path'   -MockWith { $true }
                Mock -CommandName 'Copy-Item'   -MockWith {}
            }
            It 'calls Copy-Item 3 times (cert, key, chain)' {
                _Export-PEM -Cert $script:cert
                Should -Invoke Copy-Item -Times 3 -Exactly
            }
        }

        Context '_Export-PEM — destination folder missing, user creates' {
            BeforeEach {
                $script:ri = 0
                $script:rseq = @('C:\NewDir', 'J')
                Mock -CommandName 'Read-Host' -MockWith { $r = $script:rseq[$script:ri]; $script:ri++; $r }
                Mock -CommandName 'Test-Path' -MockWith { $false }
                Mock -CommandName 'New-Item'  -MockWith {}
                Mock -CommandName 'Copy-Item' -MockWith {}
            }
            It 'calls New-Item to create directory' {
                _Export-PEM -Cert (New-FakeCertificate)
                Should -Invoke New-Item -Times 1 -Exactly
            }
        }

        Context '_Import-WinStore — not admin — returns early' {
            BeforeEach {
                $script:TUACMEIsAdmin = $false
                Mock -CommandName 'Show-StatusBar' -MockWith {}
                Mock -CommandName 'Start-Sleep'    -MockWith {}
                Mock -CommandName 'Import-PfxCertificate' -MockWith {}
            }
            It 'does not call Import-PfxCertificate' {
                _Import-WinStore -Cert (New-FakeCertificate)
                Should -Invoke Import-PfxCertificate -Times 0
            }
        }

        Context '_Import-WinStore — admin, imports to My store' {
            BeforeEach {
                $script:TUACMEIsAdmin = $true
                Mock -CommandName 'Show-Menu'             -MockWith { 0 }   # My store
                Mock -CommandName 'Import-PfxCertificate' -MockWith {}
            }
            It 'calls Import-PfxCertificate once' {
                _Import-WinStore -Cert (New-FakeCertificate)
                Should -Invoke Import-PfxCertificate -Times 1 -Exactly
            }
        }
    }
}
