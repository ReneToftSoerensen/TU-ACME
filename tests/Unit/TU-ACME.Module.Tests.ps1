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
        (Test-ModuleManifest -Path $manifestPath).Version | Should -Be ([version]'0.2.1')
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
        Mock -ModuleName 'TU-ACME' Write-TUACMEEventLog { }
        # Exit is the last item; -1 also exits, so default to immediate exit.
        Mock -ModuleName 'TU-ACME' Show-TUACMEMenu { -1 }
    }

    It 'runs the first-run wizard when config is missing' {
        Start-TUACME
        Should -Invoke -ModuleName 'TU-ACME' Invoke-TUACMEFirstRunWizard -Times 1 -Exactly
    }

    It 're-runs the wizard when the existing config is incomplete' {
        $null = New-Item -ItemType Directory -Path $env:TUACME_DATA_DIR -Force
        Set-Content -Path (Join-Path $env:TUACME_DATA_DIR 'config.json') -Value '{ "ContactEmail": "certs@example.com" }'

        Start-TUACME 3>$null

        Should -Invoke -ModuleName 'TU-ACME' Invoke-TUACMEFirstRunWizard -Times 1 -Exactly
    }

    It 'shows the main menu when config exists' {
        $null = New-Item -ItemType Directory -Path $env:TUACME_DATA_DIR -Force
        Copy-Item -Path (Join-Path $fixturesPath 'config.valid.json') -Destination (Join-Path $env:TUACME_DATA_DIR 'config.json')

        Start-TUACME

        Should -Invoke -ModuleName 'TU-ACME' Invoke-TUACMEFirstRunWizard -Times 0 -Exactly
        Should -Invoke -ModuleName 'TU-ACME' Show-TUACMEMenu -Times 1 -Exactly
    }

    It 'logs session start (event 1000) when a configured session begins (UC-8.01 / AC-F)' {
        $null = New-Item -ItemType Directory -Path $env:TUACME_DATA_DIR -Force
        Copy-Item -Path (Join-Path $fixturesPath 'config.valid.json') -Destination (Join-Path $env:TUACME_DATA_DIR 'config.json')

        Start-TUACME

        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 1000 -and $EntryType -eq 'Information'
        }
    }

    It 'does not log session start while unconfigured (wizard path)' {
        Start-TUACME

        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 0 -Exactly -ParameterFilter {
            $EventId -eq 1000
        }
    }
}

Describe 'Start-TUACME main menu dispatch (UC-4.01, UC-12.01 / AC-J.1, AC-J.2, AC-J.3)' -Tag 'Unit' {
    BeforeEach {
        $env:TUACME_DATA_DIR = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $env:TUACME_DATA_DIR -Force
        Copy-Item -Path (Join-Path $fixturesPath 'config.valid.json') -Destination (Join-Path $env:TUACME_DATA_DIR 'config.json')

        Mock -ModuleName 'TU-ACME' Write-Host { }
        Mock -ModuleName 'TU-ACME' Write-TUACMEEventLog { }
        Mock -ModuleName 'TU-ACME' Read-TUACMEKey {
            New-Object System.ConsoleKeyInfo([char]13, [System.ConsoleKey]::Enter, $false, $false, $false)
        }
    }

    It 'opens the dashboard from the menu (AC-J.1)' {
        $script:menuQueue = New-Object System.Collections.Queue
        $script:menuQueue.Enqueue(0)
        $script:menuQueue.Enqueue(-1)
        Mock -ModuleName 'TU-ACME' Show-TUACMEMenu { $script:menuQueue.Dequeue() }
        Mock -ModuleName 'TU-ACME' Show-TUACMEDashboard { }

        Start-TUACME

        Should -Invoke -ModuleName 'TU-ACME' Show-TUACMEDashboard -Times 1 -Exactly
    }

    It 'orders a certificate for the entered domain (AC-J.2)' {
        $script:menuQueue = New-Object System.Collections.Queue
        $script:menuQueue.Enqueue(1)
        $script:menuQueue.Enqueue(-1)
        Mock -ModuleName 'TU-ACME' Show-TUACMEMenu { $script:menuQueue.Dequeue() }
        Mock -ModuleName 'TU-ACME' Read-Host { 'www.example.com' }
        Mock -ModuleName 'TU-ACME' Invoke-TUACMEOrderCertificate {
            [pscustomobject]@{ Domain = 'www.example.com'; Thumbprint = 'AAA'; NotAfter = (Get-Date).AddDays(90) }
        }

        Start-TUACME

        Should -Invoke -ModuleName 'TU-ACME' Invoke-TUACMEOrderCertificate -Times 1 -Exactly -ParameterFilter {
            $Domain -eq 'www.example.com' -and $DryRun -ne $true
        }
    }

    It 'runs a dry-run order against staging (AC-J.3)' {
        $script:menuQueue = New-Object System.Collections.Queue
        $script:menuQueue.Enqueue(2)
        $script:menuQueue.Enqueue(-1)
        Mock -ModuleName 'TU-ACME' Show-TUACMEMenu { $script:menuQueue.Dequeue() }
        Mock -ModuleName 'TU-ACME' Read-Host { 'www.example.com' }
        Mock -ModuleName 'TU-ACME' Invoke-TUACMEOrderCertificate {
            [pscustomobject]@{ Domain = 'www.example.com'; Thumbprint = 'AAA'; NotAfter = (Get-Date).AddDays(90) }
        }

        Start-TUACME

        Should -Invoke -ModuleName 'TU-ACME' Invoke-TUACMEOrderCertificate -Times 1 -Exactly -ParameterFilter {
            $Domain -eq 'www.example.com' -and $DryRun -eq $true
        }
    }

    It 'renews the certificate selected from the list (AC-D.3)' {
        $script:menuQueue = New-Object System.Collections.Queue
        $script:menuQueue.Enqueue(3)
        $script:menuQueue.Enqueue(0)
        $script:menuQueue.Enqueue(-1)
        Mock -ModuleName 'TU-ACME' Show-TUACMEMenu { $script:menuQueue.Dequeue() }
        Mock -ModuleName 'TU-ACME' Get-TUACMECertificate {
            @([pscustomobject]@{ MainDomain = 'www.example.com'; Thumbprint = 'AAA'; NotAfter = (Get-Date).AddDays(10) })
        }
        Mock -ModuleName 'TU-ACME' Invoke-TUACMERenewCertificate {
            [pscustomobject]@{ Domain = 'www.example.com'; OldThumbprint = 'AAA'; NewThumbprint = 'BBB'; NotAfter = (Get-Date).AddDays(90) }
        }

        Start-TUACME

        Should -Invoke -ModuleName 'TU-ACME' Invoke-TUACMERenewCertificate -Times 1 -Exactly -ParameterFilter {
            $Domain -eq 'www.example.com'
        }
    }

    It 'requires confirmation before installing the scheduled task (UC-7.01)' {
        $script:menuQueue = New-Object System.Collections.Queue
        $script:menuQueue.Enqueue(4)
        $script:menuQueue.Enqueue(4)
        $script:menuQueue.Enqueue(-1)
        Mock -ModuleName 'TU-ACME' Show-TUACMEMenu { $script:menuQueue.Dequeue() }
        $script:confirmQueue = New-Object System.Collections.Queue
        $script:confirmQueue.Enqueue('n')
        $script:confirmQueue.Enqueue('y')
        Mock -ModuleName 'TU-ACME' Read-Host { $script:confirmQueue.Dequeue() }
        Mock -ModuleName 'TU-ACME' Install-TUACMEScheduledTask { [pscustomobject]@{ TaskName = 'TU-ACME-Renewal' } }

        Start-TUACME

        Should -Invoke -ModuleName 'TU-ACME' Install-TUACMEScheduledTask -Times 1 -Exactly
    }

    It 'clamps the menu title to 79 chars when the contact email is long (AC-C.3)' {
        $config = Get-Content -LiteralPath (Join-Path $env:TUACME_DATA_DIR 'config.json') -Raw | ConvertFrom-Json
        $config.ContactEmail = ('very-long-certificate-operations-mailbox-{0}@example.com' -f ('x' * 60))
        $config | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $env:TUACME_DATA_DIR 'config.json')
        Mock -ModuleName 'TU-ACME' Show-TUACMEMenu { -1 }

        { Start-TUACME } | Should -Not -Throw

        Should -Invoke -ModuleName 'TU-ACME' Show-TUACMEMenu -Times 1 -Exactly -ParameterFilter {
            $Title.Length -le 79
        }
    }

    It 'disables the scheduled-task item without an elevated session (UC-7.01)' {
        Mock -ModuleName 'TU-ACME' Show-TUACMEMenu { -1 }
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsAdministrator { $false }

        Start-TUACME

        Should -Invoke -ModuleName 'TU-ACME' Show-TUACMEMenu -Times 1 -Exactly -ParameterFilter {
            $DisabledIndices -contains 4
        }
    }

    It 'enables the scheduled-task item in an elevated session (UC-7.01)' {
        Mock -ModuleName 'TU-ACME' Show-TUACMEMenu { -1 }
        Mock -ModuleName 'TU-ACME' Test-TUACMEIsAdministrator { $true }

        Start-TUACME

        Should -Invoke -ModuleName 'TU-ACME' Show-TUACMEMenu -Times 1 -Exactly -ParameterFilter {
            @($DisabledIndices).Count -eq 0
        }
    }

    It 'reports operation failures in Cyan and keeps the menu loop alive (AC-C.4)' {
        $script:menuQueue = New-Object System.Collections.Queue
        $script:menuQueue.Enqueue(1)
        $script:menuQueue.Enqueue(-1)
        Mock -ModuleName 'TU-ACME' Show-TUACMEMenu { $script:menuQueue.Dequeue() }
        Mock -ModuleName 'TU-ACME' Read-Host { 'www.example.com' }
        Mock -ModuleName 'TU-ACME' Invoke-TUACMEOrderCertificate { throw 'CA unreachable' }

        { Start-TUACME } | Should -Not -Throw

        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter {
            $Object -like 'Operation failed:*CA unreachable*' -and [string]$ForegroundColor -eq 'Cyan'
        }
        Should -Invoke -ModuleName 'TU-ACME' Show-TUACMEMenu -Times 2 -Exactly
    }
}
