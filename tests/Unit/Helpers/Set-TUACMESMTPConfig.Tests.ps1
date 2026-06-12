BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
    $script:fixturesPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Fixtures'
}

Describe 'Set-TUACMESMTPConfig (UC-10.02 / AC-H.2)' -Tag 'Unit' {
    BeforeEach {
        $env:TUACME_DATA_DIR = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $env:TUACME_DATA_DIR -Force
        Copy-Item -Path (Join-Path $fixturesPath 'config.valid.json') -Destination (Join-Path $env:TUACME_DATA_DIR 'config.json')

        Mock -ModuleName 'TU-ACME' ConvertFrom-SecureString { 'ENCRYPTED-BLOB' }
    }

    It 'stores the DPAPI ciphertext, never the plaintext password' {
        InModuleScope 'TU-ACME' {
            $password = ConvertTo-SecureString -String 'hunter2-plaintext' -AsPlainText -Force
            Set-TUACMESMTPConfig -Server 'smtp.example.com' -Port 587 -Username 'mailer' -Password $password
        }

        $raw = Get-Content -LiteralPath (Join-Path $env:TUACME_DATA_DIR 'config.json') -Raw
        $raw | Should -Match 'ENCRYPTED-BLOB'
        $raw | Should -Not -Match 'hunter2-plaintext'
    }

    It 'encrypts via ConvertFrom-SecureString without a key (DPAPI per-machine)' {
        InModuleScope 'TU-ACME' {
            $password = ConvertTo-SecureString -String 'secret' -AsPlainText -Force
            Set-TUACMESMTPConfig -Server 'smtp.example.com' -Password $password
        }

        Should -Invoke -ModuleName 'TU-ACME' ConvertFrom-SecureString -Times 1 -Exactly -ParameterFilter {
            $null -eq $Key -or $Key.Count -eq 0
        }
    }

    It 'stores server, port, and username in plaintext alongside the ciphertext' {
        InModuleScope 'TU-ACME' {
            $password = ConvertTo-SecureString -String 'secret' -AsPlainText -Force
            Set-TUACMESMTPConfig -Server 'smtp.example.com' -Port 587 -Username 'mailer' -Password $password
        }

        $saved = Get-Content -LiteralPath (Join-Path $env:TUACME_DATA_DIR 'config.json') -Raw | ConvertFrom-Json
        $saved.Smtp.Server | Should -Be 'smtp.example.com'
        $saved.Smtp.Port | Should -Be 587
        $saved.Smtp.Username | Should -Be 'mailer'
        $saved.Smtp.EncryptedPassword | Should -Be 'ENCRYPTED-BLOB'
    }

    It 'preserves the rest of the configuration when adding SMTP settings' {
        InModuleScope 'TU-ACME' {
            $password = ConvertTo-SecureString -String 'secret' -AsPlainText -Force
            Set-TUACMESMTPConfig -Server 'smtp.example.com' -Password $password
        }

        $saved = Get-Content -LiteralPath (Join-Path $env:TUACME_DATA_DIR 'config.json') -Raw | ConvertFrom-Json
        $saved.ContactEmail | Should -Be 'certs@example.com'
        $saved.ProdDirectoryUrl | Should -Not -BeNullOrEmpty
    }

    It 'overwrites existing SMTP settings on reconfiguration' {
        InModuleScope 'TU-ACME' {
            $password = ConvertTo-SecureString -String 'secret' -AsPlainText -Force
            Set-TUACMESMTPConfig -Server 'old.example.com' -Password $password
            Set-TUACMESMTPConfig -Server 'new.example.com' -Password $password
        }

        $saved = Get-Content -LiteralPath (Join-Path $env:TUACME_DATA_DIR 'config.json') -Raw | ConvertFrom-Json
        $saved.Smtp.Server | Should -Be 'new.example.com'
    }
}

Describe 'Get-TUACMESMTPConfig (UC-10.02 / AC-H.2)' -Tag 'Unit' {
    BeforeEach {
        $env:TUACME_DATA_DIR = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $env:TUACME_DATA_DIR -Force
        Copy-Item -Path (Join-Path $fixturesPath 'config.valid.json') -Destination (Join-Path $env:TUACME_DATA_DIR 'config.json')
    }

    It 'returns null while SMTP is not configured' {
        $result = InModuleScope 'TU-ACME' { Get-TUACMESMTPConfig }

        $result | Should -BeNullOrEmpty
    }

    It 'decrypts the stored password via ConvertTo-SecureString' {
        Mock -ModuleName 'TU-ACME' ConvertFrom-SecureString { 'ENCRYPTED-BLOB' }
        Mock -ModuleName 'TU-ACME' ConvertTo-SecureString { New-Object System.Security.SecureString }

        $result = InModuleScope 'TU-ACME' {
            $password = New-Object System.Security.SecureString
            Set-TUACMESMTPConfig -Server 'smtp.example.com' -Port 587 -Username 'mailer' -Password $password
            Get-TUACMESMTPConfig
        }

        Should -Invoke -ModuleName 'TU-ACME' ConvertTo-SecureString -Times 1 -Exactly -ParameterFilter {
            $String -eq 'ENCRYPTED-BLOB'
        }
        $result.Server | Should -Be 'smtp.example.com'
        $result.Port | Should -Be 587
        $result.Username | Should -Be 'mailer'
        $result.Password | Should -BeOfType [System.Security.SecureString]
    }
}
