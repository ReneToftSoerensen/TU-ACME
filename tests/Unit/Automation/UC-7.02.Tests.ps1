#Requires -Modules Pester

Describe 'UC-7.02 - SMTP password persisted DPAPI-encrypted' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc702-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'collects the password via Read-Host -AsSecureString and writes smtp-credentials.xml via Export-Clixml' {
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

            $knownSecure = 'pwd' | ConvertTo-SecureString -AsPlainText -Force

            # String Read-Host answers in order:
            # 1: SMTP server, 2: port, 3: SSL, 4: UseAuth (y -> auth on),
            # 5: sender, 6: recipient, 7: username, 8: confirm (y), 9: Press Enter
            $script:_rh = 0
            $script:_answers = @(
                'smtp.example.com',
                '',
                '',
                'y',
                'noreply@example.com',
                'ops@example.com',
                'svc-tuacme',
                'y',
                ''
            )

            # Default Read-Host returns the next string answer
            Mock Read-Host {
                $v = $script:_answers[$script:_rh]
                $script:_rh++
                return $v
            }

            # Override for the -AsSecureString call: return the known SecureString
            # without consuming an entry from the string-answers list.
            Mock Read-Host -ParameterFilter { $AsSecureString } -MockWith {
                return $knownSecure
            }

            Invoke-SMTPConfigure

            Assert-MockCalled Read-Host -ParameterFilter { $AsSecureString } -Times 1 -Scope It
            Assert-MockCalled ConvertFrom-SecureString -Times 1 -Scope It
            Assert-MockCalled Export-Clixml -Times 1 -Scope It -ParameterFilter {
                $Path -like (Join-Path $env:ProgramData 'TU-ACME\smtp-credentials.xml')
            }
        }
    }
}
