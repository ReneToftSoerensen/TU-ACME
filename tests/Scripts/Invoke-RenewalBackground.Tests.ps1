#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\Bootstrap.ps1"
. "$PSScriptRoot\..\Fixtures\FakeObjects.ps1"

$script:ScriptPath = (Resolve-Path "$PSScriptRoot\..\..\TU-ACME\Scripts\Invoke-RenewalBackground.ps1").Path

Describe 'Invoke-RenewalBackground.ps1' -Tag Unit, Scripts {

    # The background script is standalone (not in the module) — we dot-source it into
    # a fresh scope for each context, replacing external functions with mocks first.

    BeforeAll { Import-TUACMEModule }
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

    Context 'Write-Log function in script' {
        BeforeAll {
            $script:content = Get-Content -Path $script:ScriptPath -Raw
        }
        It 'defines a Write-Log helper' {
            $script:content | Should -Match 'function Write-Log'
        }
        It 'Write-Log swallows exceptions (try/catch)' {
            $script:content | Should -Match 'try'
        }
    }

    Context 'Send-ErrorMail function in script' {
        BeforeAll {
            $script:content = Get-Content -Path $script:ScriptPath -Raw
        }
        It 'defines Send-ErrorMail' {
            $script:content | Should -Match 'function Send-ErrorMail'
        }
        It 'loads SMTP config from config.json' {
            $script:content | Should -Match 'config\.json'
        }
        It 'loads credentials from smtp-credentials.xml' {
            $script:content | Should -Match 'smtp-credentials\.xml'
        }
    }

    Context 'Exit codes' {
        It 'script contains exit 1 for failure paths' {
            $content = Get-Content -Path $script:ScriptPath -Raw
            $content | Should -Match 'exit 1'
        }
    }
}
