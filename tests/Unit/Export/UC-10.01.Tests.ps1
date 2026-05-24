#Requires -Modules Pester

Describe 'UC-10.01 - Export PFX prompts overwrite and calls Export-PfxCertificate' -Tag 'Unit' {
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

    It 'does not call Export-PfxCertificate when the operator declines overwriting an existing PFX' {
        InModuleScope TU-ACME {
            Mock Use-TUACMEProdAccount {}
            Mock Get-PACertificate {
                @(
                    [PSCustomObject]@{
                        Subject    = 'cn=example.com'
                        NotAfter   = (Get-Date).AddDays(60)
                        Thumbprint = 'ABC123'
                    }
                )
            }
            Mock Show-Table          {}
            Mock Show-Menu           { return 0 }   # 0 = PFX
            Mock Invoke-ConsoleClear {}
            Mock Write-EventLogEntry {}
            Mock Export-PfxCertificate {}
            Mock Test-Path           { $true }

            # Read-Host sequence:
            #   0 = certificate index           -> '1'
            #   1 = destination PFX path        -> 'C:\Temp\example.pfx'
            #   2 = overwrite (y/N)             -> 'n'
            #   (no further calls expected)
            $script:_rhCalls = 0
            Mock Read-Host {
                $i = $script:_rhCalls
                $script:_rhCalls = $i + 1
                switch ($i) {
                    0 { return '1' }
                    1 { return 'C:\Temp\example.pfx' }
                    2 { return 'n' }
                    default { return '' }
                }
            }

            Invoke-ExportMenu

            Assert-MockCalled Export-PfxCertificate -Times 0 -Scope It
            Assert-MockCalled Test-Path             -Times 1 -Scope It
        }
    }
}
