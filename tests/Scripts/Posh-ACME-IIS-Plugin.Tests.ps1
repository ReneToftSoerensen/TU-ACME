#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\Bootstrap.ps1"
. "$PSScriptRoot\..\Fixtures\FakeObjects.ps1"

Describe 'Posh-ACME-IIS-Plugin.ps1' -Tag Unit, Scripts {

    BeforeAll {
        Import-TUACMEModule
        $script:PluginPath = Join-Path $PSScriptRoot '..\..\TU-ACME\Scripts\Posh-ACME-IIS-Plugin.ps1'
    }
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
        It 'continues remaining bindings on single failure (no global exit on error)' {
            $script:content | Should -Match 'foreach.*binding'
        }
        It 'calls Import-PfxCertificate when CertFile provided' {
            $script:content | Should -Match 'Import-PfxCertificate'
        }
    }

    Context 'Refactored to be both dot-sourceable and directly runnable' {
        BeforeAll {
            $script:content = Get-Content -Path $script:PluginPath -Raw
        }
        It 'defines an Update-IISBindingForCert function' {
            $script:content | Should -Match 'function Update-IISBindingForCert'
        }
        It 'guards the direct-invocation block against dot-source' {
            $script:content | Should -Match '\$MyInvocation\.InvocationName -ne ''\.'''
        }
        It 'no longer references the nonexistent Set-PAConfig' {
            $script:content | Should -Not -Match 'Set-PAConfig'
        }
    }

    Context 'Function shape (dot-source + invoke)' {
        BeforeAll {
            # Dot-source the script — the guard prevents the direct-run
            # block from firing, but the function definition is exported
            # into our test scope.
            $script:OnWindows = $true
            . $script:PluginPath
        }

        It 'Update-IISBindingForCert is defined' {
            Get-Command Update-IISBindingForCert -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        It 'returns silently when OldThumbprint is empty (no rebind attempted)' {
            Mock -CommandName 'Get-WebBinding'        -MockWith { throw 'should not be called' }
            Mock -CommandName 'Write-EventLogEntry'   -MockWith {}
            { Update-IISBindingForCert -OldThumbprint '' -NewThumbprint 'X' } | Should -Not -Throw
            Should -Invoke Get-WebBinding -Times 0
        }
    }
}
