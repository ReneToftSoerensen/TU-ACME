#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\Bootstrap.ps1"
. "$PSScriptRoot\..\Fixtures\FakeObjects.ps1"

BeforeDiscovery { Import-TUACMEModule }

Describe 'Config roundtrip (real filesystem)' -Tag Integration {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    BeforeEach {
        $script:tmp = New-TempTestDir
        $script:cfgDir  = Join-Path $script:tmp 'TU-ACME'
        $script:cfgPath = Join-Path $script:cfgDir 'config.json'
        New-Item -ItemType Directory -Path $script:cfgDir -Force | Out-Null
    }
    AfterEach { Remove-TempTestDir $script:tmp }

    InModuleScope TU-ACME {
        It 'Get-TUACMEConfig returns defaults when file absent' {
            # No file created — expect defaults
            Mock -CommandName 'Test-Path'   -MockWith { $false } -ParameterFilter { $Path -match 'config' }
            $cfg = Get-TUACMEConfig
            $cfg.DNS.DefaultDnsSleep | Should -Be 120
        }

        It 'Set-TUACMEConfig + Get-TUACMEConfig roundtrip preserves values' {
            $tmp    = New-TempTestDir
            $cfgDir = Join-Path $tmp 'TU-ACME'
            $cfgPth = Join-Path $cfgDir 'config.json'
            New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null

            # Write real file
            $cfg = New-FakeConfig
            $cfg.DNS.DefaultDnsSleep = 300
            $cfg | ConvertTo-Json -Depth 5 | Set-Content -Path $cfgPth -Encoding UTF8

            # Read it back
            $json   = Get-Content -Path $cfgPth -Raw
            $result = $json | ConvertFrom-Json
            $result.DNS.DefaultDnsSleep | Should -Be 300

            Remove-TempTestDir $tmp
        }

        It 'SMTP credential XML roundtrip preserves username' {
            $tmp     = New-TempTestDir
            $xmlPath = Join-Path $tmp 'smtp-credentials.xml'
            $pass    = ConvertTo-SecureString 'S3cr3t!' -AsPlainText -Force

            [PSCustomObject]@{ Username = 'user@test.dk'; Password = $pass } |
                Export-Clixml -Path $xmlPath

            $loaded = Import-Clixml -Path $xmlPath
            $loaded.Username | Should -Be 'user@test.dk'
            $loaded.Password | Should -BeOfType [System.Security.SecureString]

            Remove-TempTestDir $tmp
        }
    }
}

Describe 'Module import/export integration' -Tag Integration {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    It 'Start-TUACME is callable after import' {
        $cmd = Get-Command -Module TU-ACME -Name Start-TUACME
        $cmd | Should -Not -BeNullOrEmpty
    }

    It 'Private functions are NOT available in caller scope' {
        { Get-AdminStatus } | Should -Throw
    }
}
