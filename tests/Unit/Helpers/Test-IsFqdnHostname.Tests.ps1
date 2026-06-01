#Requires -Modules Pester

Describe 'UC-9.12 - Test-IsFqdnHostname classifies hostnames correctly' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force
    }
    AfterAll {
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'accepts a normal multi-label FQDN' {
        InModuleScope TU-ACME { Test-IsFqdnHostname 'www.fragt.dk' | Should -BeTrue }
    }

    It 'accepts a deep multi-label FQDN' {
        InModuleScope TU-ACME { Test-IsFqdnHostname 'acme01.lab.fragt.root.local' | Should -BeTrue }
    }

    It 'accepts a wildcard FQDN (leftmost label only)' {
        InModuleScope TU-ACME { Test-IsFqdnHostname '*.fragt.dk' | Should -BeTrue }
    }

    It 'rejects a single-label NetBIOS-style name' {
        InModuleScope TU-ACME { Test-IsFqdnHostname 'ACME01P' | Should -BeFalse }
    }

    It 'rejects empty / whitespace' {
        InModuleScope TU-ACME {
            (Test-IsFqdnHostname '')       | Should -BeFalse
            (Test-IsFqdnHostname '   ')    | Should -BeFalse
            (Test-IsFqdnHostname $null)    | Should -BeFalse
        }
    }

    It 'rejects an IPv4 literal' {
        InModuleScope TU-ACME { Test-IsFqdnHostname '192.168.1.10' | Should -BeFalse }
    }

    It 'rejects a name with an underscore' {
        InModuleScope TU-ACME { Test-IsFqdnHostname 'bad_name.fragt.dk' | Should -BeFalse }
    }

    It 'rejects a wildcard in a non-leftmost label' {
        InModuleScope TU-ACME { Test-IsFqdnHostname 'sub.*.fragt.dk' | Should -BeFalse }
    }

    It 'rejects labels starting or ending with hyphen' {
        InModuleScope TU-ACME {
            (Test-IsFqdnHostname '-bad.fragt.dk')   | Should -BeFalse
            (Test-IsFqdnHostname 'bad-.fragt.dk')   | Should -BeFalse
        }
    }
}
