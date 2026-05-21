#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"
. "$PSScriptRoot\..\..\Fixtures\FakeObjects.ps1"

BeforeDiscovery { Import-TUACMEModule }

Describe 'Write-PALog' -Tag Unit, Helpers {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        BeforeEach {
            $script:logLines = @()
            Mock -CommandName 'Test-Path'   -MockWith { $true }
            Mock -CommandName 'New-Item'    -MockWith {}
            Mock -CommandName 'Add-Content' -MockWith { $script:logLines += $Value }
        }

        Context 'Basic shape' {
            It 'writes one line per call' {
                Write-PALog -Cmdlet 'Get-PACertificate' -BoundArgs @{ List = $true }
                $script:logLines.Count | Should -Be 1
            }
            It 'line starts with an ISO-ish timestamp' {
                Write-PALog -Cmdlet 'Get-PACertificate' -BoundArgs @{ List = $true }
                $script:logLines[0] | Should -Match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3} '
            }
            It 'line contains the cmdlet name' {
                Write-PALog -Cmdlet 'New-PAAccount' -BoundArgs @{ Contact = 'mailto:a@b.dk' }
                $script:logLines[0] | Should -Match 'New-PAAccount'
            }
            It 'records (no args) when args hashtable is empty' {
                Write-PALog -Cmdlet 'Get-PAServer' -BoundArgs @{}
                $script:logLines[0] | Should -Match '\(no args\)'
            }
            It 'records (no args) when Args is null' {
                Write-PALog -Cmdlet 'Get-PAServer'
                $script:logLines[0] | Should -Match '\(no args\)'
            }
        }

        Context 'Parameter formatting' {
            It 'formats key=value pairs sorted by key' {
                Write-PALog -Cmdlet 'Set-PAServer' -BoundArgs @{ DirectoryUrl = 'LE_STAGE'; AcceptTOS = $true }
                $script:logLines[0] | Should -Match 'AcceptTOS=True DirectoryUrl=LE_STAGE'
            }
            It 'recurses into nested hashtables (e.g. PluginArgs)' {
                $pluginArgs = @{ ZoneId = 'abc123'; ApiToken = 'should-be-hidden' }
                Write-PALog -Cmdlet 'New-PACertificate' -BoundArgs @{ Domain = 'eks.dk'; PluginArgs = $pluginArgs }
                $script:logLines[0] | Should -Match 'ZoneId=abc123'
            }
            It 'serializes arrays' {
                Write-PALog -Cmdlet 'New-PACertificate' -BoundArgs @{ Domain = @('a.dk', 'b.dk') }
                $script:logLines[0] | Should -Match 'Domain=\[a\.dk, b\.dk\]'
            }
        }

        Context 'Secret masking' {
            It 'masks values whose key contains "Token"' {
                Write-PALog -Cmdlet 'X' -BoundArgs @{ ApiToken = 'super-secret-12345' }
                $script:logLines[0] | Should -Match 'ApiToken=\*\*\*MASKED\*\*\*'
                $script:logLines[0] | Should -Not -Match 'super-secret'
            }
            It 'masks values whose key contains "Key" (case-insensitive)' {
                Write-PALog -Cmdlet 'X' -BoundArgs @{ ApiKey = 'k123' }
                $script:logLines[0] | Should -Match 'ApiKey=\*\*\*MASKED\*\*\*'
            }
            It 'masks values whose key contains "Password"' {
                Write-PALog -Cmdlet 'X' -BoundArgs @{ AdminPassword = 'hunter2' }
                $script:logLines[0] | Should -Match 'AdminPassword=\*\*\*MASKED\*\*\*'
                $script:logLines[0] | Should -Not -Match 'hunter2'
            }
            It 'masks values whose key contains "Secret"' {
                Write-PALog -Cmdlet 'X' -BoundArgs @{ ClientSecret = 'shh' }
                $script:logLines[0] | Should -Match 'ClientSecret=\*\*\*MASKED\*\*\*'
            }
            It 'masks values whose key contains "Credential"' {
                Write-PALog -Cmdlet 'X' -BoundArgs @{ DnsCredential = 'leak-me' }
                $script:logLines[0] | Should -Match 'DnsCredential=\*\*\*MASKED\*\*\*'
            }
            It 'masks secret keys inside nested PluginArgs' {
                $pluginArgs = @{ ZoneId = 'public-zone'; ApiToken = 'super-secret-12345' }
                Write-PALog -Cmdlet 'New-PACertificate' -BoundArgs @{ PluginArgs = $pluginArgs }
                $script:logLines[0] | Should -Not -Match 'super-secret'
                $script:logLines[0] | Should -Match 'ApiToken=\*\*\*MASKED\*\*\*'
            }
            It 'replaces SecureString with ***SECURESTRING***' {
                $ss = ConvertTo-SecureString -String 'x' -AsPlainText -Force
                Write-PALog -Cmdlet 'X' -BoundArgs @{ Token = $ss }
                $script:logLines[0] | Should -Match '\*\*\*MASKED\*\*\*'   # masked by key first; nested case below tests bare SS
            }
            It 'replaces a bare SecureString value when the key is not secret-named' {
                $ss = ConvertTo-SecureString -String 'x' -AsPlainText -Force
                Write-PALog -Cmdlet 'X' -BoundArgs @{ SomeHandle = $ss }
                $script:logLines[0] | Should -Match 'SomeHandle=\*\*\*SECURESTRING\*\*\*'
            }
        }

        Context 'Failure-safety' {
            It 'does not throw when Add-Content fails' {
                Mock -CommandName 'Add-Content' -MockWith { throw 'disk full' }
                { Write-PALog -Cmdlet 'Get-PACertificate' -BoundArgs @{ List = $true } } | Should -Not -Throw
            }
        }
    }
}
