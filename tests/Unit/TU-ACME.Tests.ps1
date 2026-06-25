#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' 'src' 'TU-ACME.psd1'
    Import-Module $modulePath -Force

    # On non-Windows CI the Posh-ACME module is not installed, so define guarded
    # stubs for the cmdlets the tested functions call, allowing Mock to target them.
    if (-not (Get-Command Get-PAServer -ErrorAction SilentlyContinue)) {
        function global:Get-PAServer { [CmdletBinding()] param([switch]$List) }
    }
}

Describe 'Get-OrderedIdentifiers' {
    It 'places the common name first' {
        InModuleScope TU-ACME {
            $r = Get-OrderedIdentifiers -CommonName 'cn.example.com' -Hosts @('b.example.com', 'cn.example.com', 'a.example.com')
            $r[0] | Should -Be 'cn.example.com'
        }
    }

    It 'sorts the remaining hosts and excludes the CN from the tail' {
        InModuleScope TU-ACME {
            $r = Get-OrderedIdentifiers -CommonName 'cn.example.com' -Hosts @('b.example.com', 'cn.example.com', 'a.example.com')
            $r | Should -Be @('cn.example.com', 'a.example.com', 'b.example.com')
        }
    }

    It 'returns just the CN when it is the only host' {
        InModuleScope TU-ACME {
            (Get-OrderedIdentifiers -CommonName 'only.example.com' -Hosts @('only.example.com')) |
                Should -Be @('only.example.com')
        }
    }
}

Describe 'Test-WacsHostPattern' {
    It 'matches a literal host' {
        InModuleScope TU-ACME {
            Test-WacsHostPattern -Value 'www.example.com' -Patterns @('www.example.com') | Should -BeTrue
        }
    }

    It 'matches a * wildcard' {
        InModuleScope TU-ACME {
            Test-WacsHostPattern -Value 'api.example.com' -Patterns @('*.example.com') | Should -BeTrue
        }
    }

    It 'matches a ? single character' {
        InModuleScope TU-ACME {
            Test-WacsHostPattern -Value 'a.example.com' -Patterns @('?.example.com') | Should -BeTrue
        }
    }

    It 'does not match a non-matching host' {
        InModuleScope TU-ACME {
            Test-WacsHostPattern -Value 'www.other.org' -Patterns @('*.example.com') | Should -BeFalse
        }
    }
}

Describe 'ConvertTo-ThumbprintBytes' {
    It 'round-trips a thumbprint through bytes' {
        InModuleScope TU-ACME {
            $thumb = 'AABBCCDDEEFF00112233445566778899AABBCCDD'
            $bytes = ConvertTo-ThumbprintBytes -Thumbprint $thumb
            $bytes.Length | Should -Be 20
            ([BitConverter]::ToString($bytes)).Replace('-', '') | Should -Be $thumb
        }
    }
}

Describe 'Resolve-PAServerArg' {
    It 'passes a built-in alias through unchanged' {
        InModuleScope TU-ACME {
            Resolve-PAServerArg -ServerInput 'LE_PROD' | Should -Be 'LE_PROD'
        }
    }

    It 'passes an https URL through unchanged' {
        InModuleScope TU-ACME {
            Resolve-PAServerArg -ServerInput 'https://acme.example.com/directory' |
                Should -Be 'https://acme.example.com/directory'
        }
    }

    It 'resolves a custom short name to its directory URL' {
        InModuleScope TU-ACME {
            Mock Get-PAServer { @([pscustomobject]@{ Name = 'internal'; location = 'https://acme.internal/dir' }) }
            Resolve-PAServerArg -ServerInput 'internal' | Should -Be 'https://acme.internal/dir'
        }
    }
}

Describe 'ConvertTo-DateTime / Format-PADate' {
    It 'returns a DateTime unchanged' {
        InModuleScope TU-ACME {
            $dt = [datetime]'2026-01-02T03:04:05'
            (ConvertTo-DateTime $dt) | Should -Be $dt
        }
    }

    It 'parses an ISO-8601 string' {
        InModuleScope TU-ACME {
            (ConvertTo-DateTime '2026-01-02T03:04:05').Year | Should -Be 2026
        }
    }

    It 'returns $null for empty input' {
        InModuleScope TU-ACME {
            ConvertTo-DateTime '' | Should -BeNullOrEmpty
        }
    }

    It 'formats a DateTime as ISO-8601 yyyy-MM-dd HH:mm' {
        InModuleScope TU-ACME {
            Format-PADate ([datetime]'2026-01-02T03:04:00') | Should -Be '2026-01-02 03:04'
        }
    }

    It 'formats an ISO-8601 string input' {
        InModuleScope TU-ACME {
            Format-PADate '2026-01-02T03:04:00' | Should -Be '2026-01-02 03:04'
        }
    }

    It 'returns - for unparseable input' {
        InModuleScope TU-ACME {
            Format-PADate 'not-a-date' | Should -Be '-'
        }
    }
}

Describe 'Get-PAInvalidOrdersForIdentifiers' {
    It 'returns only invalid orders overlapping the requested identifiers' {
        InModuleScope TU-ACME {
            Mock Get-PAOrdersList {
                @(
                    [pscustomobject]@{ Name = 'o1'; Identifiers = 'a.example.com,b.example.com'; Status = 'invalid' },
                    [pscustomobject]@{ Name = 'o2'; Identifiers = 'c.example.com'; Status = 'valid' },
                    [pscustomobject]@{ Name = 'o3'; Identifiers = 'x.example.com'; Status = 'invalid' }
                )
            }
            $r = Get-PAInvalidOrdersForIdentifiers -Identifiers @('a.example.com')
            $r.Count | Should -Be 1
            $r[0].Name | Should -Be 'o1'
        }
    }

    It 'returns nothing when no invalid order overlaps' {
        InModuleScope TU-ACME {
            Mock Get-PAOrdersList {
                @([pscustomobject]@{ Name = 'o1'; Identifiers = 'a.example.com'; Status = 'valid' })
            }
            @(Get-PAInvalidOrdersForIdentifiers -Identifiers @('a.example.com')).Count | Should -Be 0
        }
    }
}
