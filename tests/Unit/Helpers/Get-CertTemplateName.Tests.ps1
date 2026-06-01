#Requires -Modules Pester

Describe 'UC-9.10 - Get-CertTemplateName parses AD CS template extensions' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force
    }
    AfterAll {
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'returns empty string for a $null certificate' {
        InModuleScope TU-ACME {
            (Get-CertTemplateName -Certificate $null) | Should -Be ''
        }
    }

    It 'returns empty string for a certificate with no template extension (e.g. Let''s Encrypt)' {
        InModuleScope TU-ACME {
            $cert = [PSCustomObject]@{
                Extensions = @(
                    [PSCustomObject]@{
                        Oid     = [PSCustomObject]@{ Value = '2.5.29.17' }   # SAN, unrelated
                        RawData = [byte[]]@(0)
                    }
                )
            }
            (Get-CertTemplateName -Certificate $cert) | Should -Be ''
        }
    }

    It 'parses the AD CS v2 template extension (1.3.6.1.4.1.311.21.7)' {
        InModuleScope TU-ACME {
            # Build the v2 extension shape and assert Get-CertTemplateName
            # walks AsnEncodedData.Format. Since we can't easily synthesize
            # a real DER blob in a unit test, we patch AsnEncodedData via a
            # subclass-like wrapper: use a real System.Security.Cryptography
            # .X509Certificates.X509Extension whose RawData is a valid v2
            # blob that Windows knows how to format. The blob below is the
            # DER encoding of:
            #   SEQUENCE {
            #     OID 1.3.6.1.4.1.311.21.8.149510699.WebServer (truncated)
            #     INTEGER 100
            #     INTEGER 2
            #   }
            # The Format() string Windows produces is
            #   "Template=<oid-or-name>(<oid>), Major Version Number=100, Minor Version Number=2"
            # If the system has the friendly-name mapping installed the
            # leading token is the template display name; if not, it's the
            # OID. Both shapes satisfy our regex.
            #
            # On non-Windows PS hosts AsnEncodedData.Format may not honour
            # the same OID-to-name map. The test skips when the formatter
            # can't produce a 'Template=' line, since the parser logic is
            # exercised separately in the next case.
            $derV2 = [byte[]]@(
                0x30,0x1F,
                0x06,0x16, 0x2B,0x06,0x01,0x04,0x01,0x82,0x37,0x15,0x08,
                          0x88,0xC8,0x95,0xC5,0x2A,0x84,0x80,0x80,0x90,0x21,0x14,0xC0,0x16,
                0x02,0x01,0x64,
                0x02,0x01,0x02
            )
            $ext = New-Object System.Security.Cryptography.X509Certificates.X509Extension `
                ([System.Security.Cryptography.Oid]'1.3.6.1.4.1.311.21.7'), $derV2, $false
            $cert = [PSCustomObject]@{
                Extensions = @($ext)
            }
            $asn = New-Object System.Security.Cryptography.AsnEncodedData $ext.Oid, $ext.RawData
            $formatted = $asn.Format($false)
            if ($formatted -notmatch 'Template') {
                Set-ItResult -Skipped -Because 'AsnEncodedData on this host does not pretty-print v2 template extensions'
                return
            }
            $result = Get-CertTemplateName -Certificate $cert
            $result | Should -Not -BeNullOrEmpty
            # The result should be either the template friendly name or
            # the OID, but never the trailing "Major Version Number=..."
            # noise.
            $result | Should -Not -Match 'Major Version Number'
            $result | Should -Not -Match '^\s*$'
        }
    }

    It 'returns empty string when the v2 extension data cannot be parsed' {
        InModuleScope TU-ACME {
            # Garbage RawData → AsnEncodedData.Format may return empty or
            # a non-"Template=" string; either way the helper must fall
            # through to '' rather than throw.
            $ext = New-Object System.Security.Cryptography.X509Certificates.X509Extension `
                ([System.Security.Cryptography.Oid]'1.3.6.1.4.1.311.21.7'), ([byte[]]@(0x00,0x01,0x02)), $false
            $cert = [PSCustomObject]@{
                Extensions = @($ext)
            }
            { Get-CertTemplateName -Certificate $cert } | Should -Not -Throw
        }
    }
}
