#Requires -Modules Pester

Describe 'UC-7.01 - SMTP saves config when summary confirmed' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc701-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'calls Set-TUACMEConfig exactly once when the summary is confirmed with y' {
        InModuleScope TU-ACME {
            $cfg = [PSCustomObject]@{
                Email = [PSCustomObject]@{
                    SmtpServer       = ''
                    SmtpPort         = 587
                    UseSsl           = $true
                    UseAuth          = $true
                    SenderAddress    = ''
                    RecipientAddress = ''
                }
            }

            Mock Get-TUACMEConfig    { $cfg }
            Mock Set-TUACMEConfig    {}
            Mock ConvertFrom-SecureString { 'enc-pwd-token' }
            Mock Export-Clixml       {}
            Mock Invoke-ConsoleClear {}

            # Read-Host answers in order:
            # 1: SMTP server, 2: port, 3: SSL, 4: UseAuth (n -> skip creds),
            # 5: sender, 6: recipient, 7: confirm (y), 8: Press Enter
            $script:_rh = 0
            $script:_answers = @(
                'smtp.example.com',
                '',
                '',
                'n',
                'noreply@example.com',
                'ops@example.com',
                'y',
                ''
            )
            Mock Read-Host {
                $v = $script:_answers[$script:_rh]
                $script:_rh++
                return $v
            }

            Invoke-SMTPConfigure

            Assert-MockCalled Set-TUACMEConfig -Times 1 -Scope It -ParameterFilter {
                $Config.Email.SmtpServer       -eq 'smtp.example.com' -and
                $Config.Email.SmtpPort         -eq 587 -and
                $Config.Email.SenderAddress    -eq 'noreply@example.com' -and
                $Config.Email.RecipientAddress -eq 'ops@example.com'
            }
        }
    }

    It 'does not call Set-TUACMEConfig when the summary is declined' {
        InModuleScope TU-ACME {
            $cfg = [PSCustomObject]@{
                Email = [PSCustomObject]@{
                    SmtpServer       = ''
                    SmtpPort         = 587
                    UseSsl           = $true
                    UseAuth          = $true
                    SenderAddress    = ''
                    RecipientAddress = ''
                }
            }

            Mock Get-TUACMEConfig    { $cfg }
            Mock Set-TUACMEConfig    {}
            Mock ConvertFrom-SecureString { 'enc-pwd-token' }
            Mock Export-Clixml       {}
            Mock Invoke-ConsoleClear {}

            # Confirm = '' (default N)
            $script:_rh = 0
            $script:_answers = @(
                'smtp.example.com',
                '',
                '',
                'n',
                'noreply@example.com',
                'ops@example.com',
                '',
                ''
            )
            Mock Read-Host {
                $v = $script:_answers[$script:_rh]
                $script:_rh++
                return $v
            }

            Invoke-SMTPConfigure

            Assert-MockCalled Set-TUACMEConfig -Times 0 -Scope It
        }
    }
}
