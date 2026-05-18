#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"
. "$PSScriptRoot\..\..\Fixtures\FakeObjects.ps1"

Describe 'Invoke-OrderCertificate' -Tag Unit, Certificates {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        BeforeEach {
            Mock -CommandName 'Write-Host'            -MockWith {}
            Mock -CommandName 'Invoke-ConsoleClear'   -MockWith {}
            Mock -CommandName 'Invoke-ConsoleWaitKey' -MockWith {}
            Mock -CommandName 'Show-Menu'             -MockWith { 0 }
            Mock -CommandName 'Show-Spinner'          -MockWith { New-FakeCertificate }
            Mock -CommandName 'Get-TUACMEConfig'      -MockWith { New-FakeConfig }
            Mock -CommandName 'Set-TUACMEConfig'      -MockWith {}
            Mock -CommandName 'Get-PAPlugin'          -MockWith { @(New-FakePlugin 'Cloudflare') }
            Mock -CommandName 'Get-PAPluginArgs'      -MockWith { New-FakePluginArgs }
            Mock -CommandName 'New-PACertificate'     -MockWith { New-FakeCertificate }
        }

        Context '_Select-DNSPlugin — plugins available' {
            It 'returns selected plugin name' {
                Mock -CommandName 'Show-Menu' -MockWith { 0 }
                $r = _Select-DNSPlugin
                $r | Should -Not -BeNullOrEmpty
            }
        }

        Context '_Select-DNSPlugin — no plugins, falls back to Manual' {
            BeforeEach {
                Mock -CommandName 'Get-PAPlugin' -MockWith { @() }
            }
            It 'returns Manual' {
                $r = _Select-DNSPlugin
                $r | Should -Be 'Manual'
            }
        }

        Context '_Select-DNSPlugin — user presses ESC' {
            BeforeEach {
                Mock -CommandName 'Show-Menu' -MockWith { -1 }
            }
            It 'returns null' {
                $r = _Select-DNSPlugin
                $r | Should -BeNullOrEmpty
            }
        }

        Context '_Configure-DNS01Challenge — defaults from config' {
            BeforeEach {
                Mock -CommandName 'Read-Host' -MockWith { '' }   # blanks — use defaults
            }
            It 'returns DnsSleep 120 from defaults' {
                $r = _Configure-DNS01Challenge -Plugin 'Cloudflare'
                $r.DnsSleep | Should -Be 120
            }
            It 'returns ValidationTimeout 60 from defaults' {
                $r = _Configure-DNS01Challenge -Plugin 'Cloudflare'
                $r.ValidationTimeout | Should -Be 60
            }
            It 'returns PersistentRecords false by default' {
                $r = _Configure-DNS01Challenge -Plugin 'Cloudflare'
                $r.PersistentRecords | Should -BeFalse
            }
        }

        Context '_Configure-DNS01Challenge — custom DnsSleep entered' {
            BeforeEach {
                $script:ri = 0
                $script:readSeq = @('300', '', 'N', 'N')  # sleep=300, timeout blank, not persistent, no save
                Mock -CommandName 'Read-Host' -MockWith { $r = $script:readSeq[$script:ri]; $script:ri++; $r }
            }
            It 'returns DnsSleep 300' {
                $r = _Configure-DNS01Challenge -Plugin 'Cloudflare'
                $r.DnsSleep | Should -Be 300
            }
        }

        Context '_Configure-DNS01Challenge — Manual plugin, persistent info shown' {
            BeforeEach {
                Mock -CommandName 'Read-Host' -MockWith { '' }
            }
            It 'does not throw for Manual plugin' {
                { _Configure-DNS01Challenge -Plugin 'Manual' } | Should -Not -Throw
            }
        }

        Context '_Collect-AcmeDnsArgs — reuses existing account' {
            BeforeEach {
                Mock -CommandName 'Get-AcmeDnsAccountPath' -MockWith { 'C:\fake\eksempel_dk.json' }
                Mock -CommandName 'Get-Content' -MockWith { (New-FakeAcmeDnsAccount | ConvertTo-Json) }
                Mock -CommandName 'Read-Host'   -MockWith { 'J' }   # reuse
            }
            It 'returns hashtable with ACMEDnsServer and ACMEDnsAccountJson' {
                $r = _Collect-AcmeDnsArgs -Domains @('eksempel.dk')
                $r | Should -Not -BeNullOrEmpty
                $r.ContainsKey('ACMEDnsAccountJson') | Should -BeTrue
            }
        }
    }
}
