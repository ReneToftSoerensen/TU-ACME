#Requires -Modules Pester

Describe 'UC-10.02 - Export PEM concatenates chain and key' -Tag 'Unit' {
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

    It 'reads chain + key and writes their concatenation to the destination' {
        InModuleScope TU-ACME {
            Mock Use-TUACMEProdAccount {}

            # First Get-PACertificate (-List) returns the listing; second
            # call (-MainDomain) returns the resolved cert with file paths.
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
            Mock Show-Menu           { return 1 }   # 1 = PEM
            Mock Invoke-ConsoleClear {}
            Mock Write-EventLogEntry {}
            Mock Test-Path           { $false }     # destination does not exist
            Mock Get-Content {
                if ($LiteralPath -eq 'C:\Temp\fakefullchain.pem') { return 'CHAIN-CONTENTS' }
                if ($LiteralPath -eq 'C:\Temp\fakekey.pem')       { return 'KEY-CONTENTS' }
                return ''
            }
            Mock Set-Content {}

            # Read-Host sequence: index, destination path
            $script:_rhCalls = 0
            Mock Read-Host {
                $i = $script:_rhCalls
                $script:_rhCalls = $i + 1
                switch ($i) {
                    0 { return '1' }
                    1 { return 'C:\Temp\example.pem' }
                    default { return '' }
                }
            }

            Invoke-ExportMenu

            Assert-MockCalled Get-Content -Times 1 -Scope It -ParameterFilter {
                $LiteralPath -eq 'C:\Temp\fakefullchain.pem'
            }
            Assert-MockCalled Get-Content -Times 1 -Scope It -ParameterFilter {
                $LiteralPath -eq 'C:\Temp\fakekey.pem'
            }
            Assert-MockCalled Set-Content -Times 1 -Scope It -ParameterFilter {
                $LiteralPath -eq 'C:\Temp\example.pem' -and
                $Value -match 'CHAIN-CONTENTS' -and
                $Value -match 'KEY-CONTENTS'
            }
        }
    }
}
