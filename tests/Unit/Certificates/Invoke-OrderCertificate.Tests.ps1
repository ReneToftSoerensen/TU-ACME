#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"
. "$PSScriptRoot\..\..\Fixtures\FakeObjects.ps1"

BeforeDiscovery { Import-TUACMEModule }

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
                Mock -CommandName 'Read-Host'   -MockWith { 'Y' }   # reuse
            }
            It 'returns hashtable with ACMEDnsServer and ACMEDnsAccountJson' {
                $r = _Collect-AcmeDnsArgs -Domains @('eksempel.dk')
                $r | Should -Not -BeNullOrEmpty
                $r.ContainsKey('ACMEDnsAccountJson') | Should -BeTrue
            }
        }

        Context '_Collect-HTTP01Args — user provides webroot path' {
            BeforeEach {
                Mock -CommandName 'Read-Host' -MockWith { 'C:\inetpub\wwwroot' }
            }
            It 'returns hashtable with WRPath key' {
                $r = _Collect-HTTP01Args
                $r | Should -Not -BeNullOrEmpty
                $r.ContainsKey('WRPath') | Should -BeTrue
            }
            It 'WRPath equals the entered path' {
                $r = _Collect-HTTP01Args
                $r.WRPath | Should -Be 'C:\inetpub\wwwroot'
            }
            It 'trims surrounding whitespace from the path' {
                Mock -CommandName 'Read-Host' -MockWith { '   /var/www/html   ' }
                $r = _Collect-HTTP01Args
                $r.WRPath | Should -Be '/var/www/html'
            }
        }

        Context '_Collect-HTTP01Args — user enters blank to cancel' {
            BeforeEach {
                Mock -CommandName 'Read-Host' -MockWith { '' }
            }
            It 'returns null' {
                $r = _Collect-HTTP01Args
                $r | Should -BeNullOrEmpty
            }
        }

        Context '_Collect-HTTP01SelfHostArgs — defaults (blank port + blank timeout)' {
            BeforeEach {
                Mock -CommandName 'Read-Host' -MockWith { '' }
            }
            It 'returns WSHPort empty (== Posh-ACME port 80 default)' {
                $r = _Collect-HTTP01SelfHostArgs
                $r.WSHPort | Should -Be ''
            }
            It 'returns WSHTimeout 120 (Posh-ACME default)' {
                $r = _Collect-HTTP01SelfHostArgs
                $r.WSHTimeout | Should -Be 120
            }
        }

        Context '_Collect-HTTP01SelfHostArgs — custom port + custom timeout' {
            BeforeEach {
                $script:ri = 0
                $script:rseq = @('8080', '300')
                Mock -CommandName 'Read-Host' -MockWith { $r = $script:rseq[$script:ri]; $script:ri++; $r }
            }
            It 'returns the entered port' {
                $r = _Collect-HTTP01SelfHostArgs
                $r.WSHPort | Should -Be '8080'
            }
            It 'returns the entered timeout' {
                $r = _Collect-HTTP01SelfHostArgs
                $r.WSHTimeout | Should -Be 300
            }
        }

        Context '_Collect-HTTP01SelfHostArgs — invalid port falls back to 80' {
            BeforeEach {
                $script:ri = 0
                $script:rseq = @('not-a-port', '')
                Mock -CommandName 'Read-Host' -MockWith { $r = $script:rseq[$script:ri]; $script:ri++; $r }
            }
            It 'returns WSHPort empty (falls back to default)' {
                $r = _Collect-HTTP01SelfHostArgs
                $r.WSHPort | Should -Be ''
            }
        }

        Context '_Collect-HTTP01SelfHostArgs — out-of-range port falls back to 80' {
            BeforeEach {
                $script:ri = 0
                $script:rseq = @('99999', '')
                Mock -CommandName 'Read-Host' -MockWith { $r = $script:rseq[$script:ri]; $script:ri++; $r }
            }
            It 'returns WSHPort empty' {
                $r = _Collect-HTTP01SelfHostArgs
                $r.WSHPort | Should -Be ''
            }
        }

        Context '_Collect-HTTP01SelfHostArgs — invalid timeout falls back to 120' {
            BeforeEach {
                $script:ri = 0
                $script:rseq = @('', 'banana')
                Mock -CommandName 'Read-Host' -MockWith { $r = $script:rseq[$script:ri]; $script:ri++; $r }
            }
            It 'returns WSHTimeout 120' {
                $r = _Collect-HTTP01SelfHostArgs
                $r.WSHTimeout | Should -Be 120
            }
        }
    }
}
