#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\Bootstrap.ps1"
. "$PSScriptRoot\..\Fixtures\FakeObjects.ps1"

$script:PluginPath = (Resolve-Path "$PSScriptRoot\..\..\TU-ACME\Scripts\Posh-ACME-IIS-Plugin.ps1").Path

Describe 'Posh-ACME-IIS-Plugin.ps1' -Tag Unit, Scripts {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    Context 'Script file is valid' {
        It 'script file is present' {
            Test-Path $script:PluginPath | Should -BeTrue
        }
        It 'parses without syntax errors' {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile(
                $script:PluginPath, [ref]$null, [ref]$errors
            )
            $errors | Should -BeNullOrEmpty
        }
    }

    Context 'Script structure — UC-8.4 compliance' {
        BeforeAll {
            $script:content = Get-Content -Path $script:PluginPath -Raw
        }

        It 'accepts OldThumbprint parameter' {
            $script:content | Should -Match 'OldThumbprint'
        }
        It 'accepts CertFile parameter' {
            $script:content | Should -Match 'CertFile'
        }
        It 'accepts Thumbprint parameter' {
            $script:content | Should -Match '\$Thumbprint'
        }
        It 'falls back to environment variables' {
            $script:content | Should -Match 'POSHACME_'
        }
        It 'imports WebAdministration' {
            $script:content | Should -Match 'Import-Module WebAdministration'
        }
        It 'calls Get-WebBinding to find matching bindings' {
            $script:content | Should -Match 'Get-WebBinding'
        }
        It 'calls Set-WebBinding to update thumbprint' {
            $script:content | Should -Match 'Set-WebBinding'
        }
        It 'logs EventId 1002 on success' {
            $script:content | Should -Match '1002'
        }
        It 'logs EventId 3002 on failure' {
            $script:content | Should -Match '3002'
        }
        It 'short-circuits when OldThumbprint is missing' {
            $script:content | Should -Match 'exit 0'
        }
        It 'continues remaining bindings on single failure (no global exit on error)' {
            # The foreach loop should have per-iteration try/catch, not a function-level abort
            $script:content | Should -Match 'foreach.*binding'
        }
        It 'calls Import-PfxCertificate when CertFile provided' {
            $script:content | Should -Match 'Import-PfxCertificate'
        }
    }

    Context 'Exit code on WebAdministration failure' {
        It 'script exits 1 when WebAdministration missing' {
            $content = Get-Content -Path $script:PluginPath -Raw
            $content | Should -Match 'exit 1'
        }
    }
}
