BeforeAll {
    . (Join-Path (Split-Path -Parent $PSScriptRoot) 'Bootstrap.ps1')
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:manifestPath = Join-Path (Join-Path $repoRoot 'TU-ACME') 'TU-ACME.psd1'
    $script:fixturesPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Fixtures'
}

Describe 'TU-ACME module (UC-1.01)' -Tag 'Unit' {
    It 'has a valid module manifest' {
        { Test-ModuleManifest -Path $manifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'exposes a readable module version' {
        (Test-ModuleManifest -Path $manifestPath).Version | Should -Be ([version]'0.1.0')
    }

    It 'imports without errors' {
        { Import-Module $manifestPath -ArgumentList $true -Force -ErrorAction Stop } | Should -Not -Throw
    }

    It 'exports exactly the public cmdlets' {
        $commands = @(Get-Command -Module 'TU-ACME')
        $commands.Name | Should -Be @('Start-TUACME')
    }

    It 'does not export private helpers' {
        Get-Command -Module 'TU-ACME' -Name 'Get-TUACMEConfig' -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }
}

Describe 'Start-TUACME (UC-1.02 entry point)' -Tag 'Unit' {
    BeforeEach {
        $env:TUACME_DATA_DIR = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        Mock -ModuleName 'TU-ACME' Invoke-TUACMEFirstRunWizard { [pscustomobject]@{} }
        Mock -ModuleName 'TU-ACME' Write-Host { }
    }

    It 'runs the first-run wizard when config is missing' {
        Start-TUACME
        Should -Invoke -ModuleName 'TU-ACME' Invoke-TUACMEFirstRunWizard -Times 1 -Exactly
    }

    It 'shows the configuration summary when config exists' {
        $null = New-Item -ItemType Directory -Path $env:TUACME_DATA_DIR -Force
        Copy-Item -Path (Join-Path $fixturesPath 'config.valid.json') -Destination (Join-Path $env:TUACME_DATA_DIR 'config.json')

        Start-TUACME

        Should -Invoke -ModuleName 'TU-ACME' Invoke-TUACMEFirstRunWizard -Times 0 -Exactly
        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter { $Object -like '*certs@example.com*' }
    }
}
