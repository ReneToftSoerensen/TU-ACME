BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Convert-TUACMEThumbprintToByte (issue #16)' -Tag 'Unit' {
    It 'converts a hex thumbprint to the matching bytes' {
        $result = InModuleScope 'TU-ACME' { Convert-TUACMEThumbprintToByte -Thumbprint 'AABBCC' }

        @($result).Count | Should -Be 3
        $result[0] | Should -Be 170
        $result[1] | Should -Be 187
        $result[2] | Should -Be 204
    }

    It 'strips spaces and dashes before converting' {
        $result = InModuleScope 'TU-ACME' { Convert-TUACMEThumbprintToByte -Thumbprint 'AA BB-CC' }

        @($result).Count | Should -Be 3
        $result[2] | Should -Be 204
    }

    It 'returns a byte array' {
        $result = InModuleScope 'TU-ACME' { Convert-TUACMEThumbprintToByte -Thumbprint 'FFEE' }

        ($result -is [byte[]]) | Should -BeTrue
        $result[0] | Should -Be 255
    }
}
