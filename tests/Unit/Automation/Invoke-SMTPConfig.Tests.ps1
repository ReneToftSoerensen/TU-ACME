#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
. "$PSScriptRoot\..\..\Bootstrap.ps1"
. "$PSScriptRoot\..\..\Fixtures\FakeObjects.ps1"

Describe 'Invoke-SMTPConfig' -Tag Unit, Automation {

    BeforeAll { Import-TUACMEModule }
    AfterAll  { Remove-TUACMEModule }

    InModuleScope TU-ACME {
        BeforeEach {
            Mock -CommandName 'Write-Host'            -MockWith {}
            Mock -CommandName 'Invoke-ConsoleClear'   -MockWith {}
            Mock -CommandName 'Invoke-ConsoleWaitKey' -MockWith {}
            Mock -CommandName 'Get-TUACMEConfig'      -MockWith { New-FakeConfig }
            Mock -CommandName 'Set-TUACMEConfig'      -MockWith {}
            Mock -CommandName 'Export-Clixml'         -MockWith {}
            Mock -CommandName 'Send-TUACMEMail'       -MockWith { $true }
            $script:ri = 0
            # server, port, ssl, sender, recipient, auth, test-mail
            $script:rseq = @('smtp.test.dk', '587', 'N', 'from@test.dk', 'to@test.dk', 'N', 'N')
            Mock -CommandName 'Read-Host' -MockWith { $r = $script:rseq[$script:ri]; $script:ri++; $r }
        }

        Context 'Basic config without auth — saves config' {
            It 'calls Set-TUACMEConfig once' {
                Invoke-SMTPConfig
                Should -Invoke Set-TUACMEConfig -Times 1 -Exactly
            }
            It 'does not call Export-Clixml when no auth' {
                Invoke-SMTPConfig
                Should -Invoke Export-Clixml -Times 0
            }
        }

        Context 'Auth enabled — saves encrypted credentials' {
            BeforeEach {
                $script:ri = 0
                $script:rseq = @('smtp.test.dk', '587', 'N', 'from@test.dk', 'to@test.dk', 'J', 'N')
                Mock -CommandName 'Read-Host' -MockWith { $r = $script:rseq[$script:ri]; $script:ri++; $r }
                $script:ki = 0
                $script:kseq = @(
                    (New-Object System.ConsoleKeyInfo('p', [System.ConsoleKey]::P, $false, $false, $false)),
                    (New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Enter, $false, $false, $false))
                )
                Mock -CommandName 'Invoke-ConsoleReadKey' -MockWith {
                    $k = $script:kseq[$script:ki]; $script:ki++; return $k
                }
            }
            It 'calls Export-Clixml once' {
                Invoke-SMTPConfig
                Should -Invoke Export-Clixml -Times 1 -Exactly
            }
        }

        Context 'Test mail requested after save' {
            BeforeEach {
                $script:ri = 0
                $script:rseq = @('smtp.test.dk', '', '', '', '', 'N', 'J')  # accept many defaults, then test
                Mock -CommandName 'Read-Host' -MockWith { $r = $script:rseq[$script:ri]; $script:ri++; $r }
            }
            It 'calls Send-TUACMEMail' {
                Invoke-SMTPConfig
                Should -Invoke Send-TUACMEMail -Times 1 -Exactly
            }
        }
    }
}
