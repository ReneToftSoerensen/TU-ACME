BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')

    function script:Set-ReadHostQueue {
        param([object[]]$Answers)
        $script:readHostQueue = New-Object System.Collections.Queue
        foreach ($answer in $Answers) { $script:readHostQueue.Enqueue($answer) }
    }
}

Describe 'Get-TUACMEOrderDomain manual fallback (UC-5.03)' -Tag 'Unit' {
    BeforeEach {
        # No candidates: exercise the existing manual Read-Host flow unchanged.
        Mock -ModuleName 'TU-ACME' Get-TUACMESystemNameCandidate { @() }
        Mock -ModuleName 'TU-ACME' Show-TUACMEMultiSelectMenu { throw 'multi-select should not run without candidates' }
        Mock -ModuleName 'TU-ACME' Show-TUACMEMenu { throw 'CN menu should not run without candidates' }
        Mock -ModuleName 'TU-ACME' Read-Host { $script:readHostQueue.Dequeue() }
    }

    It 'accepts the proposed short-hostname SAN default on Enter' {
        # FQDN, then blank (Enter) accepts the default short hostname SAN.
        Set-ReadHostQueue @('host.example.com', '')

        $result = InModuleScope 'TU-ACME' {
            Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)'
        }

        @($result) | Should -Be @('host.example.com', 'host')
    }

    It 'skips the SAN with the "-" sentinel and returns just the FQDN' {
        Set-ReadHostQueue @('host.example.com', '-')

        $result = InModuleScope 'TU-ACME' {
            Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)'
        }

        @($result) | Should -Be @('host.example.com')
    }

    It 'overrides the default SAN with a typed value' {
        Set-ReadHostQueue @('host.example.com', 'alias')

        $result = InModuleScope 'TU-ACME' {
            Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)'
        }

        @($result) | Should -Be @('host.example.com', 'alias')
    }

    It 'de-dupes a single-label FQDN to one name' {
        # The default SAN equals the FQDN, so the order collapses to one name.
        Set-ReadHostQueue @('host', '')

        $result = InModuleScope 'TU-ACME' {
            Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)'
        }

        @($result) | Should -Be @('host')
    }

    It 'returns an empty array when the FQDN is blank' {
        Set-ReadHostQueue @('')

        $result = InModuleScope 'TU-ACME' {
            Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)'
        }

        @($result).Count | Should -Be 0
    }
}

Describe 'Get-TUACMEOrderDomain quick-pick (UC-5.04 / AC-D.6)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Get-TUACMESystemNameCandidate {
            @(
                [pscustomobject]@{ Name = 'host.example.com'; Source = 'FQDN' }
                [pscustomobject]@{ Name = 'host'; Source = 'Hostname' }
                [pscustomobject]@{ Name = 'www.example.com'; Source = 'IIS' }
            )
        }
        Mock -ModuleName 'TU-ACME' Read-Host { $script:readHostQueue.Dequeue() }
    }

    It 'returns the single picked name without prompting via Read-Host' {
        Mock -ModuleName 'TU-ACME' Show-TUACMEMultiSelectMenu { @(0) }
        Mock -ModuleName 'TU-ACME' Show-TUACMEMenu { throw 'CN menu should not run for a single pick' }

        $result = InModuleScope 'TU-ACME' {
            Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)'
        }

        @($result) | Should -Be @('host.example.com')
        Should -Invoke -ModuleName 'TU-ACME' Read-Host -Times 0
    }

    It 'prompts for the CN when multiple names are picked and puts the CN first' {
        Mock -ModuleName 'TU-ACME' Show-TUACMEMultiSelectMenu { @(0, 2) }
        # Picked names are @('host.example.com','www.example.com'); choose index 1
        # (www.example.com) as the CN, leaving host.example.com as the SAN.
        Mock -ModuleName 'TU-ACME' Show-TUACMEMenu { 1 }

        $result = InModuleScope 'TU-ACME' {
            Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)'
        }

        @($result) | Should -Be @('www.example.com', 'host.example.com')
        Should -Invoke -ModuleName 'TU-ACME' Read-Host -Times 0
    }

    It 'falls back to manual entry when the multi-select is cancelled (Esc)' {
        Mock -ModuleName 'TU-ACME' Show-TUACMEMultiSelectMenu { $null }
        Mock -ModuleName 'TU-ACME' Show-TUACMEMenu { throw 'CN menu should not run on cancel' }
        Set-ReadHostQueue @('manual.example.com', '-')

        $result = InModuleScope 'TU-ACME' {
            Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)'
        }

        @($result) | Should -Be @('manual.example.com')
        Should -Invoke -ModuleName 'TU-ACME' Read-Host -Times 2
    }

    It 'falls back to manual entry when the selection is confirmed empty' {
        Mock -ModuleName 'TU-ACME' Show-TUACMEMultiSelectMenu { @() }
        Mock -ModuleName 'TU-ACME' Show-TUACMEMenu { throw 'CN menu should not run on empty selection' }
        Set-ReadHostQueue @('manual.example.com', '-')

        $result = InModuleScope 'TU-ACME' {
            Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)'
        }

        @($result) | Should -Be @('manual.example.com')
        Should -Invoke -ModuleName 'TU-ACME' Read-Host -Times 2
    }

    It 'returns an empty array when the CN prompt is cancelled after a multi-select' {
        Mock -ModuleName 'TU-ACME' Show-TUACMEMultiSelectMenu { @(0, 2) }
        Mock -ModuleName 'TU-ACME' Show-TUACMEMenu { -1 }

        $result = InModuleScope 'TU-ACME' {
            Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)'
        }

        @($result).Count | Should -Be 0
        Should -Invoke -ModuleName 'TU-ACME' Read-Host -Times 0
    }
}
