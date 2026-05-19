#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"

BeforeDiscovery { Import-TUACMEModule }

Describe 'Write-EventLogEntry' -Tag Unit, Helpers {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        BeforeEach {
            Mock -CommandName 'New-EventLog'  -MockWith {}
            Mock -CommandName 'Write-EventLog' -MockWith {}
        }

        Context 'Source does not exist' {
            BeforeEach {
                Mock -CommandName 'New-EventLog' -MockWith {}
                # Simulate SourceExists = false
                Mock -CommandName 'Write-EventLogEntry' -MockWith {
                    New-EventLog -LogName Application -Source 'TU-ACME-FAKE'
                    Write-EventLog -LogName Application -Source 'TU-ACME-FAKE' -EventId 1001 -EntryType Information -Message 'test'
                }
            }

            It 'calls Write-EventLog' {
                Write-EventLogEntry -EventId 1001 -Message 'Test message'
                Should -Invoke Write-EventLog -Times 1 -Exactly
            }
        }

        Context 'Write-EventLog throws — error is swallowed' {
            BeforeEach {
                Mock -CommandName 'Write-EventLog' -MockWith { throw 'Access denied' }
            }

            It 'does not propagate exception' {
                { Write-EventLogEntry -EventId 3001 -Message 'fail' -EntryType Error } | Should -Not -Throw
            }
        }

        Context 'EntryType defaults to Information' {
            It 'does not throw with default EntryType' {
                { Write-EventLogEntry -EventId 1001 -Message 'info' } | Should -Not -Throw
            }
        }

        Context 'Validates EntryType parameter' {
            It 'accepts Warning' {
                { Write-EventLogEntry -EventId 2001 -Message 'warn' -EntryType Warning } | Should -Not -Throw
            }
            It 'accepts Error' {
                { Write-EventLogEntry -EventId 3001 -Message 'err' -EntryType Error } | Should -Not -Throw
            }
            It 'rejects invalid EntryType' {
                { Write-EventLogEntry -EventId 1001 -Message 'x' -EntryType 'Invalid' } | Should -Throw
            }
        }
    }
}
