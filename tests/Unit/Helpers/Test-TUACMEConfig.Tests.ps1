BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')

    function script:New-ValidConfig {
        [pscustomobject]@{
            ContactEmail        = 'certs@example.com'
            ProdDirectoryUrl    = 'https://acme.example.com/prod/directory'
            ProdAccountId       = 'prod-1'
            StagingDirectoryUrl = 'https://acme.example.com/staging/directory'
            StagingAccountId    = 'staging-1'
        }
    }
}

Describe 'Test-TUACMEConfig (UC-10.01 / AC-H.1)' -Tag 'Unit' {
    It 'accepts a complete configuration' {
        $config = New-ValidConfig

        $result = InModuleScope 'TU-ACME' -Parameters @{ Config = $config } {
            param($Config)
            Test-TUACMEConfig -Config $Config
        }

        $result | Should -BeTrue
    }

    It 'rejects a directory URL that is not a full https URL' {
        # Posh-ACME saved-server short names (e.g. "acme") pass a
        # presence-only check but explode inside Set-PAServer.
        $config = New-ValidConfig
        $config.ProdDirectoryUrl = 'acme'

        $result = InModuleScope 'TU-ACME' -Parameters @{ Config = $config } {
            param($Config)
            Test-TUACMEConfig -Config $Config
        }

        $result | Should -BeFalse
    }

    It 'names the offending URL field when throwing' {
        $config = New-ValidConfig
        $config.StagingDirectoryUrl = 'http://insecure.example.com/dir'

        {
            InModuleScope 'TU-ACME' -Parameters @{ Config = $config } {
                param($Config)
                Test-TUACMEConfig -Config $Config -ThrowOnInvalid
            }
        } | Should -Throw '*StagingDirectoryUrl*https://*'
    }

    It 'still reports missing fields before URL shape' {
        $config = New-ValidConfig
        $config.ContactEmail = ''

        {
            InModuleScope 'TU-ACME' -Parameters @{ Config = $config } {
                param($Config)
                Test-TUACMEConfig -Config $Config -ThrowOnInvalid
            }
        } | Should -Throw '*missing required field*ContactEmail*'
    }
}
