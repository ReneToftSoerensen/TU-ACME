#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"
. "$PSScriptRoot\..\..\Fixtures\FakeObjects.ps1"

BeforeDiscovery { Import-TUACMEModule }

Describe 'Invoke-CertificateDashboard' -Tag Unit, Certificates {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        BeforeEach {
            Mock -CommandName 'Write-Host'            -MockWith {}
            Mock -CommandName 'Invoke-ConsoleClear'   -MockWith {}
            Mock -CommandName 'Invoke-ConsoleWaitKey' -MockWith {}
            Mock -CommandName 'Get-TUACMEConfig'      -MockWith { New-FakeConfig }
            Mock -CommandName 'Show-Table'            -MockWith { -1 }   # ESC — exit loop
            Mock -CommandName 'Show-StatusBar'        -MockWith {}
        }

        Context 'No certificates — shows message and returns' {
            BeforeEach {
                Mock -CommandName 'Get-PACertificate' -MockWith { @() }
            }
            It 'does not throw' {
                { Invoke-CertificateDashboard } | Should -Not -Throw
            }
            It 'calls Show-Table zero times (empty path)' {
                Invoke-CertificateDashboard
                Should -Invoke Show-Table -Times 0
            }
        }

        Context 'Certificates exist — Show-Table called with data' {
            BeforeEach {
                Mock -CommandName 'Get-PACertificate' -MockWith {
                    @(New-FakeCertificate, New-FakeWarnCertificate, New-FakeExpiredCertificate)
                }
            }
            It 'calls Show-Table once' {
                Invoke-CertificateDashboard
                Should -Invoke Show-Table -Times 1 -Exactly
            }
        }

        Context 'Row selected — cert detail shown' {
            BeforeEach {
                Mock -CommandName 'Get-PACertificate' -MockWith { @(New-FakeCertificate) }
                $script:tableCall = 0
                Mock -CommandName 'Show-Table' -MockWith {
                    if ($script:tableCall -eq 0) { $script:tableCall++; return 0 }
                    return -1
                }
                Mock -CommandName 'Invoke-ExportMenu' -MockWith {}
                Mock -CommandName 'Submit-Renewal'    -MockWith {}
                Mock -CommandName 'Invoke-ConsoleReadKey' -MockWith {
                    New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Escape, $false, $false, $false)
                }
            }
            It 'enters detail view without throwing' {
                { Invoke-CertificateDashboard } | Should -Not -Throw
            }
        }
    }
}
