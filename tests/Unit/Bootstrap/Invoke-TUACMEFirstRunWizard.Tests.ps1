BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')
}

Describe 'Invoke-TUACMEFirstRunWizard (UC-1.02)' -Tag 'Unit' {
    BeforeEach {
        $env:TUACME_DATA_DIR = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $global:TUACMETestSaves = @()
        $global:TUACMETestSwitches = @()
        $global:TUACMETestAccounts = 0

        Mock -ModuleName 'TU-ACME' Read-Host { 'certs@example.com' } -ParameterFilter {
            $Prompt -like '*email*'
        }
        Mock -ModuleName 'TU-ACME' Read-Host { 'https://acme.example.com/prod/directory' } -ParameterFilter {
            $Prompt -like 'Production*'
        }
        Mock -ModuleName 'TU-ACME' Read-Host { 'https://acme.example.com/staging/directory' } -ParameterFilter {
            $Prompt -like 'Staging*'
        }
        Mock -ModuleName 'TU-ACME' Save-TUACMEConfig {
            $global:TUACMETestSaves += , ($Config | Select-Object -Property *)
        }
        Mock -ModuleName 'TU-ACME' Use-TUACMEProdAccount {
            $global:TUACMETestSwitches += 'prod'
            'https://previous.example/dir'
        }
        Mock -ModuleName 'TU-ACME' Use-TUACMEStagingAccount {
            $global:TUACMETestSwitches += 'staging'
            'https://previous.example/dir'
        }
        Mock -ModuleName 'TU-ACME' New-PAAccount {
            $global:TUACMETestAccounts++
            if ($global:TUACMETestAccounts -eq 1) {
                [pscustomobject]@{ id = 'prod-account-1' }
            }
            else {
                [pscustomobject]@{ id = 'staging-account-1' }
            }
        }
        Mock -ModuleName 'TU-ACME' Write-TUACMEEventLog { }
        Mock -ModuleName 'TU-ACME' Write-Host { }
    }

    AfterEach {
        Remove-Variable -Name 'TUACMETestSaves', 'TUACMETestSwitches', 'TUACMETestAccounts' -Scope Global -ErrorAction SilentlyContinue
    }

    It 'creates exactly two accounts with the entered email' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMEFirstRunWizard }

        Should -Invoke -ModuleName 'TU-ACME' New-PAAccount -Times 2 -Exactly -ParameterFilter {
            ($Contact -contains 'certs@example.com') -and $AcceptTOS
        }
    }

    It 'persists the complete config with both account ids' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMEFirstRunWizard }

        $finalSave = $global:TUACMETestSaves[-1]
        $finalSave.ContactEmail | Should -Be 'certs@example.com'
        $finalSave.ProdDirectoryUrl | Should -Be 'https://acme.example.com/prod/directory'
        $finalSave.ProdAccountId | Should -Be 'prod-account-1'
        $finalSave.StagingDirectoryUrl | Should -Be 'https://acme.example.com/staging/directory'
        $finalSave.StagingAccountId | Should -Be 'staging-account-1'
    }

    It 'saves a partial config before the accounts exist' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMEFirstRunWizard }

        $firstSave = $global:TUACMETestSaves[0]
        $firstSave.ContactEmail | Should -Be 'certs@example.com'
        $firstSave.ProdAccountId | Should -BeNullOrEmpty
        $firstSave.StagingAccountId | Should -BeNullOrEmpty
    }

    It 'writes Event Log entry 1010 on completion' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMEFirstRunWizard }

        Should -Invoke -ModuleName 'TU-ACME' Write-TUACMEEventLog -Times 1 -Exactly -ParameterFilter {
            $EventId -eq 1010 -and $EntryType -eq 'Information'
        }
    }

    It 'ends with the production context active' {
        $null = InModuleScope 'TU-ACME' { Invoke-TUACMEFirstRunWizard }

        $global:TUACMETestSwitches[-1] | Should -Be 'prod'
        @($global:TUACMETestSwitches | Where-Object { $_ -eq 'staging' }).Count | Should -Be 1
    }

    It 'returns the completed configuration' {
        $result = InModuleScope 'TU-ACME' { Invoke-TUACMEFirstRunWizard }

        $result.ProdAccountId | Should -Be 'prod-account-1'
        $result.StagingAccountId | Should -Be 'staging-account-1'
    }

    It 'fails when New-PAAccount does not return an account id' {
        Mock -ModuleName 'TU-ACME' New-PAAccount { $null }

        { InModuleScope 'TU-ACME' { Invoke-TUACMEFirstRunWizard } } | Should -Throw '*account id*'
    }
}
