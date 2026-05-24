#Requires -Modules Pester

Describe 'UC-10.03 - Import to Windows store calls Import-PfxCertificate' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        if (-not (Get-Command Export-PfxCertificate -ErrorAction SilentlyContinue)) {
            & (Get-Module TU-ACME) {
                function script:Export-PfxCertificate { param($Cert,$FilePath,$Password) }
                function script:Import-PfxCertificate { param($FilePath,$CertStoreLocation,$Password) }
            }
        }
    }
    AfterAll {
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'calls Import-PfxCertificate against LocalMachine\My and emits Event 1011' {
        InModuleScope TU-ACME {
            Mock Use-TUACMEProdAccount {}

            # Get-PACertificate -List then Get-PACertificate -MainDomain
            $script:_gpaCalls = 0
            Mock Get-PACertificate {
                $i = $script:_gpaCalls
                $script:_gpaCalls = $i + 1
                if ($i -eq 0) {
                    return @(
                        [PSCustomObject]@{
                            Subject    = 'cn=example.com'
                            NotAfter   = (Get-Date).AddDays(60)
                            Thumbprint = 'ABC123'
                        }
                    )
                }
                return [PSCustomObject]@{
                    FullChainFile = 'C:\Temp\fakefullchain.pem'
                    KeyFile       = 'C:\Temp\fakekey.pem'
                    PfxFile       = 'C:\Temp\fake.pfx'
                    PfxPass       = 'pass'
                }
            }

            Mock Show-Table          {}
            Mock Show-Menu           { return 2 }   # 2 = Import to store
            Mock Invoke-ConsoleClear {}
            Mock Write-EventLogEntry {}
            Mock Import-PfxCertificate {
                [PSCustomObject]@{ Thumbprint = 'DEF456' }
            }

            # Read-Host: only the certificate index is requested.
            $script:_rhCalls = 0
            Mock Read-Host {
                $i = $script:_rhCalls
                $script:_rhCalls = $i + 1
                if ($i -eq 0) { return '1' }
                return ''
            }

            Invoke-ExportMenu

            Assert-MockCalled Import-PfxCertificate -Times 1 -Scope It -ParameterFilter {
                $CertStoreLocation -eq 'Cert:\LocalMachine\My' -and
                $FilePath          -eq 'C:\Temp\fake.pfx'
            }
            Assert-MockCalled Write-EventLogEntry -Times 1 -Scope It -ParameterFilter {
                $EventId -eq 1011
            }
        }
    }
}
