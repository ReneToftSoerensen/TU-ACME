#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"
. "$PSScriptRoot\..\..\Fixtures\FakeObjects.ps1"

BeforeDiscovery { Import-TUACMEModule }

Describe 'Invoke-AcmeDnsSetup' -Tag Unit, Helpers {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        BeforeEach {
            Mock -CommandName 'Write-Host'          -MockWith {}
            Mock -CommandName 'Read-Host'           -MockWith { 'https://auth.acme-dns.io' }
            Mock -CommandName 'Invoke-WebRequest'   -MockWith { [PSCustomObject]@{ StatusCode = 405 } }
            Mock -CommandName 'Invoke-RestMethod'   -MockWith { New-FakeAcmeDnsAccount }
            Mock -CommandName 'Invoke-ConsoleReadKey' -MockWith {
                New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Enter, $false, $false, $false)
            }
            Mock -CommandName 'Invoke-ConsoleWaitKey' -MockWith {}
            Mock -CommandName 'New-Item'            -MockWith {}
            Mock -CommandName 'Test-Path'           -MockWith { $false }
            Mock -CommandName 'Set-Content'         -MockWith {}
            Mock -CommandName 'Export-Clixml'       -MockWith {}
        }

        Context '_Register-NewAccount — success' {
            It 'returns account data object' {
                $r = _Register-NewAccount -Server 'https://auth.acme-dns.io'
                $r | Should -Not -BeNullOrEmpty
                $r.username | Should -Not -BeNullOrEmpty
                $r.fulldomain | Should -Not -BeNullOrEmpty
            }
        }

        Context '_Register-NewAccount — Invoke-RestMethod throws' {
            BeforeEach {
                Mock -CommandName 'Invoke-RestMethod' -MockWith { throw 'connection refused' }
                Mock -CommandName 'Invoke-ConsoleWaitKey' -MockWith {}
            }
            It 'returns null without throwing' {
                $r = _Register-NewAccount -Server 'https://auth.acme-dns.io'
                $r | Should -BeNullOrEmpty
            }
        }

        Context 'Get-AcmeDnsAccountPath — file exists' {
            BeforeEach {
                Mock -CommandName 'Test-Path' -MockWith { $true }
            }
            It 'returns a path string' {
                $r = Get-AcmeDnsAccountPath -Domain 'eksempel.dk'
                $r | Should -Match 'eksempel_dk\.json'
            }
        }

        Context 'Get-AcmeDnsAccountPath — file missing' {
            BeforeEach {
                Mock -CommandName 'Test-Path' -MockWith { $false }
            }
            It 'returns null' {
                $r = Get-AcmeDnsAccountPath -Domain 'eksempel.dk'
                $r | Should -BeNullOrEmpty
            }
        }

        Context '_Save-AcmeDnsAccount — creates directory and saves JSON' {
            It 'calls Set-Content once' {
                _Save-AcmeDnsAccount -AccountData (New-FakeAcmeDnsAccount) -Domains @('eksempel.dk')
                Should -Invoke Set-Content -Times 1 -Exactly
            }
            It 'calls Export-Clixml for DPAPI backup' {
                _Save-AcmeDnsAccount -AccountData (New-FakeAcmeDnsAccount) -Domains @('eksempel.dk')
                Should -Invoke Export-Clixml -Times 1 -Exactly
            }
            It 'returns path containing sanitized domain' {
                $r = _Save-AcmeDnsAccount -AccountData (New-FakeAcmeDnsAccount) -Domains @('eksempel.dk')
                $r | Should -Match 'eksempel_dk'
            }
        }

        Context '_Show-CnameInstruction — Enter continues' {
            It 'returns true on Enter' {
                $r = _Show-CnameInstruction -Domains @('eksempel.dk') -AccountData (New-FakeAcmeDnsAccount)
                $r | Should -BeTrue
            }
        }

        Context '_Show-CnameInstruction — ESC cancels' {
            BeforeEach {
                Mock -CommandName 'Invoke-ConsoleReadKey' -MockWith {
                    New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Escape, $false, $false, $false)
                }
            }
            It 'returns false on ESC' {
                $r = _Show-CnameInstruction -Domains @('eksempel.dk') -AccountData (New-FakeAcmeDnsAccount)
                $r | Should -BeFalse
            }
        }
    }
}
