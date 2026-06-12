BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
    $script:fixturesPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Fixtures'
}

Describe 'Set-TUACMEDNSConfig (UC-10.03 / AC-H.3)' -Tag 'Unit' {
    BeforeEach {
        $env:TUACME_DATA_DIR = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $env:TUACME_DATA_DIR -Force
        Copy-Item -Path (Join-Path $fixturesPath 'config.valid.json') -Destination (Join-Path $env:TUACME_DATA_DIR 'config.json')

        Mock -ModuleName 'TU-ACME' ConvertFrom-SecureString { 'ENCRYPTED-BLOB' }
    }

    It 'stores ciphertext for every plugin argument, never plaintext' {
        InModuleScope 'TU-ACME' {
            $token = ConvertTo-SecureString -String 'api-token-plaintext' -AsPlainText -Force
            Set-TUACMEDNSConfig -PluginName 'Cloudflare' -PluginArgs @{ CFToken = $token }
        }

        $raw = Get-Content -LiteralPath (Join-Path $env:TUACME_DATA_DIR 'config.json') -Raw
        $raw | Should -Match 'ENCRYPTED-BLOB'
        $raw | Should -Not -Match 'api-token-plaintext'
    }

    It 'encrypts plain-string argument values as well' {
        InModuleScope 'TU-ACME' {
            Set-TUACMEDNSConfig -PluginName 'Cloudflare' -PluginArgs @{ CFToken = 'plain-string-secret' }
        }

        $raw = Get-Content -LiteralPath (Join-Path $env:TUACME_DATA_DIR 'config.json') -Raw
        $raw | Should -Not -Match 'plain-string-secret'
        Should -Invoke -ModuleName 'TU-ACME' ConvertFrom-SecureString -Times 1 -Exactly
    }

    It 'stores the plugin name in plaintext' {
        InModuleScope 'TU-ACME' {
            Set-TUACMEDNSConfig -PluginName 'Cloudflare' -PluginArgs @{ CFToken = 'secret' }
        }

        $saved = Get-Content -LiteralPath (Join-Path $env:TUACME_DATA_DIR 'config.json') -Raw | ConvertFrom-Json
        $saved.Dns.PluginName | Should -Be 'Cloudflare'
    }

    It 'encrypts each argument via keyless ConvertFrom-SecureString (DPAPI per-machine)' {
        InModuleScope 'TU-ACME' {
            Set-TUACMEDNSConfig -PluginName 'Cloudflare' -PluginArgs @{ A = 'one'; B = 'two' }
        }

        Should -Invoke -ModuleName 'TU-ACME' ConvertFrom-SecureString -Times 2 -Exactly -ParameterFilter {
            $null -eq $Key -or $Key.Count -eq 0
        }
    }
}

Describe 'Get-TUACMEDNSConfig (UC-10.03 / AC-H.3)' -Tag 'Unit' {
    BeforeEach {
        $env:TUACME_DATA_DIR = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $env:TUACME_DATA_DIR -Force
        Copy-Item -Path (Join-Path $fixturesPath 'config.valid.json') -Destination (Join-Path $env:TUACME_DATA_DIR 'config.json')
    }

    It 'returns null while DNS is not configured' {
        $result = InModuleScope 'TU-ACME' { Get-TUACMEDNSConfig }

        $result | Should -BeNullOrEmpty
    }

    It 'decrypts stored arguments back to SecureStrings keyed by name' {
        Mock -ModuleName 'TU-ACME' ConvertFrom-SecureString { 'ENCRYPTED-BLOB' }
        Mock -ModuleName 'TU-ACME' ConvertTo-SecureString { New-Object System.Security.SecureString }

        $result = InModuleScope 'TU-ACME' {
            Set-TUACMEDNSConfig -PluginName 'Cloudflare' -PluginArgs @{ CFToken = (New-Object System.Security.SecureString) }
            Get-TUACMEDNSConfig
        }

        Should -Invoke -ModuleName 'TU-ACME' ConvertTo-SecureString -Times 1 -Exactly -ParameterFilter {
            $String -eq 'ENCRYPTED-BLOB'
        }
        $result.PluginName | Should -Be 'Cloudflare'
        $result.PluginArgs.Keys | Should -Be @('CFToken')
        $result.PluginArgs['CFToken'] | Should -BeOfType [System.Security.SecureString]
    }
}
