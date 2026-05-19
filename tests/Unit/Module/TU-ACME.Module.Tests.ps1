#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"

Describe 'TU-ACME Module Contract' -Tag Unit, Module {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    Context 'Manifest (TU-ACME.psd1)' {
        BeforeAll {
            $psd1 = Join-Path $PSScriptRoot '..\..\..\TU-ACME\TU-ACME.psd1'
            $script:manifest = Test-ModuleManifest -Path $psd1 -ErrorAction Stop
        }

        It 'passes Test-ModuleManifest' {
            $script:manifest | Should -Not -BeNullOrEmpty
        }
        It 'exports exactly Start-TUACME' {
            $script:manifest.ExportedFunctions.Keys | Should -Be @('Start-TUACME')
        }
        It 'declares PowerShellVersion 5.1' {
            $script:manifest.PowerShellVersion | Should -Be '5.1'
        }
        It 'has a non-empty GUID' {
            $script:manifest.Guid | Should -Not -BeNullOrEmpty
        }
        It 'has ModuleVersion' {
            $script:manifest.Version | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Module loading (TU-ACME.psm1)' {
        It 'imports without error' {
            { Import-TUACMEModule } | Should -Not -Throw
        }
        It 'exports Start-TUACME as a function' {
            $cmd = Get-Command -Module TU-ACME -Name Start-TUACME -ErrorAction SilentlyContinue
            $cmd | Should -Not -BeNullOrEmpty
            $cmd.CommandType | Should -Be 'Function'
        }
        It 'does not export private helpers' {
            $exported = (Get-Module TU-ACME).ExportedFunctions.Keys
            $exported | Should -Not -Contain 'Get-AdminStatus'
            $exported | Should -Not -Contain 'Show-Menu'
            $exported | Should -Not -Contain 'Invoke-ConsoleReadKey'
        }
        It 'loads all Private helper functions into module scope' {
            InModuleScope TU-ACME {
                { Get-AdminStatus } | Should -Not -Throw
                { Get-TUACMEConfig } | Should -Not -Throw
            }
        }
    }
}
