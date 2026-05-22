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
            Mock -CommandName 'Get-PAServer'          -MockWith { [PSCustomObject]@{ Name = 'LE_PROD'; location = 'https://acme-v02.api.letsencrypt.org/directory' } }
            Mock -CommandName 'Get-PAAccount'         -MockWith { [PSCustomObject]@{ id = 'acc-001'; status = 'valid' } }
            Mock -CommandName 'Set-PAServer'          -MockWith {}
            Mock -CommandName 'Set-PAAccount'         -MockWith {}
        }

        Context 'No certificates — shows message and returns' {
            BeforeEach {
                Mock -CommandName 'Get-TUACMEAllCertificates' -MockWith { @() }
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
                Mock -CommandName 'Get-TUACMEAllCertificates' -MockWith {
                    @(
                        (New-FakeCertificate)
                        (New-FakeWarnCertificate)
                        (New-FakeExpiredCertificate)
                    )
                }
            }
            It 'calls Show-Table once' {
                Invoke-CertificateDashboard
                Should -Invoke Show-Table -Times 1 -Exactly
            }
        }

        Context 'Row selected — cert detail shown' {
            BeforeEach {
                Mock -CommandName 'Get-TUACMEAllCertificates' -MockWith { @(New-FakeCertificate) }
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

        Context "Detail view — 'D' confirmed deletes certificate" {
            BeforeEach {
                $taggedCert = New-FakeCertificate
                Add-Member -InputObject $taggedCert -NotePropertyName 'ServerName' -NotePropertyValue 'LE_STAGE' -Force
                Add-Member -InputObject $taggedCert -NotePropertyName 'AccountID'  -NotePropertyValue 'acc-001'  -Force
                Mock -CommandName 'Get-TUACMEAllCertificates' -MockWith { @($taggedCert) }
                $script:tableCall = 0
                Mock -CommandName 'Show-Table' -MockWith {
                    if ($script:tableCall -eq 0) { $script:tableCall++; return 0 }
                    return -1
                }
                Mock -CommandName 'Invoke-ConsoleReadKey' -MockWith {
                    New-Object System.ConsoleKeyInfo([char]'d', [System.ConsoleKey]::D, $false, $false, $false)
                }
                Mock -CommandName 'Confirm-YesNo'           -MockWith { $true }
                Mock -CommandName '_Remove-TUACMECertDir'   -MockWith {}
                Mock -CommandName 'Write-EventLogEntry'     -MockWith {}
            }
            It 'calls _Remove-TUACMECertDir with the cert' {
                Invoke-CertificateDashboard
                Should -Invoke _Remove-TUACMECertDir -Times 1
            }
        }

        Context "Detail view — 'D' cancelled does NOT delete" {
            BeforeEach {
                Mock -CommandName 'Get-TUACMEAllCertificates' -MockWith { @(New-FakeCertificate) }
                $script:tableCall = 0
                Mock -CommandName 'Show-Table' -MockWith {
                    if ($script:tableCall -eq 0) { $script:tableCall++; return 0 }
                    return -1
                }
                Mock -CommandName 'Invoke-ConsoleReadKey' -MockWith {
                    New-Object System.ConsoleKeyInfo([char]'d', [System.ConsoleKey]::D, $false, $false, $false)
                }
                Mock -CommandName 'Confirm-YesNo'         -MockWith { $false }
                Mock -CommandName '_Remove-TUACMECertDir' -MockWith {}
            }
            It 'does NOT call _Remove-TUACMECertDir when user declines' {
                Invoke-CertificateDashboard
                Should -Invoke _Remove-TUACMECertDir -Times 0
            }
        }

        Context "Detail view — 'V' confirmed revokes certificate at ACME server" {
            BeforeEach {
                $taggedCert = New-FakeCertificate
                Add-Member -InputObject $taggedCert -NotePropertyName 'ServerName' -NotePropertyValue 'LE_STAGE' -Force
                Add-Member -InputObject $taggedCert -NotePropertyName 'AccountID'  -NotePropertyValue 'acc-001'  -Force
                Mock -CommandName 'Get-TUACMEAllCertificates' -MockWith { @($taggedCert) }
                $script:tableCall = 0
                Mock -CommandName 'Show-Table' -MockWith {
                    if ($script:tableCall -eq 0) { $script:tableCall++; return 0 }
                    return -1
                }
                Mock -CommandName 'Invoke-ConsoleReadKey' -MockWith {
                    New-Object System.ConsoleKeyInfo([char]'v', [System.ConsoleKey]::V, $false, $false, $false)
                }
                Mock -CommandName 'Confirm-YesNo'        -MockWith { $true }
                Mock -CommandName '_Invoke-TUACMERevoke' -MockWith {}
                Mock -CommandName 'Write-EventLogEntry'  -MockWith {}
            }
            It 'calls _Invoke-TUACMERevoke exactly once' {
                Invoke-CertificateDashboard
                Should -Invoke _Invoke-TUACMERevoke -Times 1 -Exactly
            }
        }

        Context "Detail view — 'V' cancelled does NOT revoke" {
            BeforeEach {
                Mock -CommandName 'Get-TUACMEAllCertificates' -MockWith { @(New-FakeCertificate) }
                $script:tableCall = 0
                Mock -CommandName 'Show-Table' -MockWith {
                    if ($script:tableCall -eq 0) { $script:tableCall++; return 0 }
                    return -1
                }
                Mock -CommandName 'Invoke-ConsoleReadKey' -MockWith {
                    New-Object System.ConsoleKeyInfo([char]'v', [System.ConsoleKey]::V, $false, $false, $false)
                }
                Mock -CommandName 'Confirm-YesNo'        -MockWith { $false }
                Mock -CommandName '_Invoke-TUACMERevoke' -MockWith {}
            }
            It 'does NOT call _Invoke-TUACMERevoke when user declines' {
                Invoke-CertificateDashboard
                Should -Invoke _Invoke-TUACMERevoke -Times 0
            }
        }

        Context "Detail view — 'F' force-renews with new key" {
            BeforeEach {
                Mock -CommandName 'Get-TUACMEAllCertificates' -MockWith { @(New-FakeCertificate) }
                $script:tableCall = 0
                Mock -CommandName 'Show-Table' -MockWith {
                    if ($script:tableCall -eq 0) { $script:tableCall++; return 0 }
                    return -1
                }
                Mock -CommandName 'Invoke-ConsoleReadKey' -MockWith {
                    New-Object System.ConsoleKeyInfo([char]'f', [System.ConsoleKey]::F, $false, $false, $false)
                }
                Mock -CommandName 'Confirm-YesNo'            -MockWith { $true }
                Mock -CommandName '_Invoke-TUACMEForceRenew' -MockWith {}
                Mock -CommandName 'Write-EventLogEntry'      -MockWith {}
            }
            It 'calls _Invoke-TUACMEForceRenew exactly once' {
                Invoke-CertificateDashboard
                Should -Invoke _Invoke-TUACMEForceRenew -Times 1 -Exactly
            }
        }

        Context 'Entry context restored on exit' {
            BeforeEach {
                Mock -CommandName 'Get-TUACMEAllCertificates' -MockWith { @() }
            }
            It 'restores the entry server URL when leaving the dashboard' {
                Invoke-CertificateDashboard
                Should -Invoke Set-PAServer -ParameterFilter {
                    $DirectoryUrl -eq 'https://acme-v02.api.letsencrypt.org/directory'
                }
            }
        }
    }
}
