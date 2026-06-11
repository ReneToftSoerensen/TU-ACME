BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Initialize-TUACMEEnvironment (UC-1.02 / AC-H.1)' -Tag 'Unit' {
    BeforeEach {
        $env:TUACME_DATA_DIR = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        Mock -ModuleName 'TU-ACME' Import-TUACMEPoshACME { $true }
        Mock -ModuleName 'TU-ACME' Invoke-TUACMEFirstRunWizard { }
        Mock -ModuleName 'TU-ACME' Get-TUACMEConfig {
            [pscustomobject]@{ ContactEmail = 'certs@example.com' }
        }
    }

    It 'loads the existing config and skips the wizard' {
        $null = New-Item -ItemType Directory -Path $env:TUACME_DATA_DIR -Force
        Set-Content -Path (Join-Path $env:TUACME_DATA_DIR 'config.json') -Value '{}'

        InModuleScope 'TU-ACME' { Initialize-TUACMEEnvironment }

        Should -Invoke -ModuleName 'TU-ACME' Get-TUACMEConfig -Times 1 -Exactly
        Should -Invoke -ModuleName 'TU-ACME' Invoke-TUACMEFirstRunWizard -Times 0 -Exactly
    }

    It 'warns and never launches the wizard when config is missing' {
        $warnings = @(InModuleScope 'TU-ACME' { Initialize-TUACMEEnvironment } 3>&1)

        $warnings[-1].Message | Should -BeLike '*Run Start-TUACME*'
        Should -Invoke -ModuleName 'TU-ACME' Invoke-TUACMEFirstRunWizard -Times 0 -Exactly
    }

    It 'warns when Posh-ACME is unavailable but does not throw' {
        Mock -ModuleName 'TU-ACME' Import-TUACMEPoshACME { $false }

        $warnings = @(InModuleScope 'TU-ACME' { Initialize-TUACMEEnvironment } 3>&1)

        @($warnings | Where-Object { $_.Message -like '*Posh-ACME is not installed*' }).Count |
            Should -Be 1
    }

    It 'sets POSHACME_HOME on Windows when unset' {
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsWindows { $true }
        $previousProgramData = $env:ProgramData
        $previousPoshAcmeHome = $env:POSHACME_HOME
        try {
            $env:ProgramData = $TestDrive
            $env:POSHACME_HOME = ''

            $null = InModuleScope 'TU-ACME' { Initialize-TUACMEEnvironment } 3>&1

            $env:POSHACME_HOME | Should -Be (Join-Path $TestDrive 'Posh-ACME')
        }
        finally {
            $env:ProgramData = $previousProgramData
            $env:POSHACME_HOME = $previousPoshAcmeHome
        }
    }
}
