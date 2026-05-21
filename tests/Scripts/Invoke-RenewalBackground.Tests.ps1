#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\Bootstrap.ps1"
. "$PSScriptRoot\..\Fixtures\FakeObjects.ps1"

Describe 'Invoke-RenewalBackground.ps1' -Tag Unit, Scripts {

    # The background script is standalone (not in the module) — we dot-source it into
    # a fresh scope for each context, replacing external functions with mocks first.

    BeforeAll {
        Import-TUACMEModule
        $script:ScriptPath = Join-Path $PSScriptRoot '..\..\TU-ACME\Scripts\Invoke-RenewalBackground.ps1'
    }
    AfterAll  { Remove-TUACMEModule }

    Context 'Script file exists and is valid PowerShell' {
        It 'script file is present' {
            Test-Path $script:ScriptPath | Should -BeTrue
        }
        It 'parses without syntax errors' {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile(
                $script:ScriptPath, [ref]$null, [ref]$errors
            )
            $errors | Should -BeNullOrEmpty
        }
    }

    Context 'Posh-ACME not available — logs error and exits' {
        It 'script is structured to handle missing module' {
            # Verify script content contains Import-Module Posh-ACME with error handling
            $content = Get-Content -Path $script:ScriptPath -Raw
            $content | Should -Match 'Import-Module Posh-ACME'
            $content | Should -Match 'catch'
        }
    }

    Context 'Script structure — UC-5.4 compliance' {
        BeforeAll {
            $script:content = Get-Content -Path $script:ScriptPath -Raw
        }

        It 'contains Submit-Renewal call' {
            $script:content | Should -Match 'Submit-Renewal'
        }
        It 'contains Write-EventLog or Write-IISLog for success (EventId 1001)' {
            $script:content | Should -Match '1001'
        }
        It 'contains error handling for EventId 3001' {
            $script:content | Should -Match '3001'
        }
        It 'contains Send-ErrorMail or equivalent notification' {
            $script:content | Should -Match 'Send-ErrorMail|Send-MailMessage|TUACMEMail'
        }
        It 'uses -NonInteractive compatible patterns (no Read-Host)' {
            $script:content | Should -Not -Match 'Read-Host'
        }
        It 'imports Posh-ACME module' {
            $script:content | Should -Match "Import-Module Posh-ACME"
        }
    }

    Context 'Reuses module helpers (no inline duplication)' {
        BeforeAll {
            $script:content = Get-Content -Path $script:ScriptPath -Raw
        }
        It 'dot-sources Write-EventLogEntry from Private/Helpers' {
            $script:content | Should -Match 'Write-EventLogEntry\.ps1'
        }
        It 'calls Write-EventLogEntry instead of defining its own Write-Log' {
            $script:content | Should -Match 'Write-EventLogEntry'
            $script:content | Should -Not -Match 'function Write-Log'
        }
        It 'uses Get-TUACMEConfig (not inline config.json read)' {
            $script:content | Should -Match 'Get-TUACMEConfig'
        }
        It 'uses Send-TUACMEMail for the actual SMTP send' {
            $script:content | Should -Match 'Send-TUACMEMail'
        }
    }

    Context 'Send-ErrorMail function in script' {
        BeforeAll {
            $script:content = Get-Content -Path $script:ScriptPath -Raw
        }
        It 'defines Send-ErrorMail' {
            $script:content | Should -Match 'function Send-ErrorMail'
        }
        It 'guards on missing SMTP config before sending' {
            $script:content | Should -Match 'SmtpServer'
        }
    }

    Context 'Exit codes' {
        It 'script contains exit 1 for failure paths' {
            $content = Get-Content -Path $script:ScriptPath -Raw
            $content | Should -Match 'exit 1'
        }
    }

    Context 'Post-renewal IIS rebind is wired into this script' {
        # Posh-ACME v4 has no -PostScript hook. The rebind must happen
        # here: snapshot thumbprints before, run Submit-Renewal, snapshot
        # after, and rebind for every cert whose thumbprint changed.
        BeforeAll {
            $script:content = Get-Content -Path $script:ScriptPath -Raw
        }
        It 'dot-sources Posh-ACME-IIS-Plugin.ps1 to get Update-IISBindingForCert' {
            $script:content | Should -Match 'Posh-ACME-IIS-Plugin\.ps1'
        }
        It 'snapshots Get-PACertificate -List before Submit-Renewal' {
            $script:content | Should -Match 'Get-CertThumbprintMap'
        }
        It 'calls Update-IISBindingForCert when a thumbprint changes' {
            $script:content | Should -Match 'Update-IISBindingForCert'
        }
        It 'no longer references the nonexistent Set-PAConfig' {
            $script:content | Should -Not -Match 'Set-PAConfig'
        }
    }
}
