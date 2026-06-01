#Requires -Modules Pester

Describe 'UC-9.11 - IIS order-from-bindings flow' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force

        if (-not (Get-Command Get-WebBinding -ErrorAction SilentlyContinue)) {
            & (Get-Module TU-ACME) {
                function script:Get-WebBinding { param($Protocol) }
            }
        }
    }
    AfterAll {
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    # Pester Mock bodies are NOT closures: variables from the enclosing
    # test scope (or passed via InModuleScope -Parameters) are NOT
    # visible to a Mock body, which runs in the module's own script
    # scope. The pattern below works around that by assigning the
    # binding fixture to $script:_bindings _inside_ InModuleScope; the
    # Mock body then reads it via the same $script: path.

    It "bundle=Yes: calls Invoke-OrderCertificate once with primary+SANs from all selected sites' hostnames" {
        InModuleScope TU-ACME {
            $script:_bindings = @(
                [PSCustomObject]@{
                    ItemXPath          = "/system.applicationHost/sites/site[@name='Acme']"
                    protocol           = 'https'
                    bindingInformation = '*:443:ACME01P.fragt.root.local'
                },
                [PSCustomObject]@{
                    ItemXPath          = "/system.applicationHost/sites/site[@name='Acme']"
                    protocol           = 'https'
                    bindingInformation = '*:443:ACME01P'
                },
                [PSCustomObject]@{
                    ItemXPath          = "/system.applicationHost/sites/site[@name='acmetest']"
                    protocol           = 'https'
                    bindingInformation = '*:443:acmetest.fragt.root.local'
                },
                [PSCustomObject]@{
                    ItemXPath          = "/system.applicationHost/sites/site[@name='acmetest']"
                    protocol           = 'https'
                    bindingInformation = '*:443:acmetest'
                },
                [PSCustomObject]@{
                    ItemXPath          = "/system.applicationHost/sites/site[@name='acmedns']"
                    protocol           = 'https'
                    bindingInformation = '*:443:acmedns.fragt.root.local'
                }
            )

            Mock Use-TUACMEProdAccount   {}
            Mock Get-WebBinding          { return $script:_bindings }
            Mock Write-Host              {}
            Mock Read-Host               { '' }
            $script:_lineCall = 0
            Mock Read-LineOrEscape {
                param($Prompt)
                $script:_lineCall++
                switch ($script:_lineCall) {
                    1 { return 'all' }
                    2 { return 'Y'   }
                    default { return '' }
                }
            }
            $script:_orderCalls = @()
            Mock Invoke-OrderCertificate {
                param($Domain, [string[]]$Sans)
                $script:_orderCalls += [PSCustomObject]@{
                    Domain = $Domain
                    Sans   = if ($Sans) { @($Sans) } else { @() }
                }
            }

            Invoke-IISOrderFromBindings

            $script:_orderCalls.Count     | Should -Be 1
            $script:_orderCalls[0].Domain | Should -Be 'ACME01P.fragt.root.local'
            $script:_orderCalls[0].Sans   | Should -Contain 'ACME01P'
            $script:_orderCalls[0].Sans   | Should -Contain 'acmetest.fragt.root.local'
            $script:_orderCalls[0].Sans   | Should -Contain 'acmetest'
            $script:_orderCalls[0].Sans   | Should -Contain 'acmedns.fragt.root.local'
            $script:_orderCalls[0].Sans.Count | Should -Be 4
        }
    }

    It 'bundle=No: calls Invoke-OrderCertificate once per hostname with no SANs' {
        InModuleScope TU-ACME {
            $script:_bindings = @(
                [PSCustomObject]@{ ItemXPath="/system.applicationHost/sites/site[@name='Acme']";     protocol='https'; bindingInformation='*:443:ACME01P.fragt.root.local' },
                [PSCustomObject]@{ ItemXPath="/system.applicationHost/sites/site[@name='Acme']";     protocol='https'; bindingInformation='*:443:ACME01P' },
                [PSCustomObject]@{ ItemXPath="/system.applicationHost/sites/site[@name='acmetest']"; protocol='https'; bindingInformation='*:443:acmetest.fragt.root.local' },
                [PSCustomObject]@{ ItemXPath="/system.applicationHost/sites/site[@name='acmetest']"; protocol='https'; bindingInformation='*:443:acmetest' },
                [PSCustomObject]@{ ItemXPath="/system.applicationHost/sites/site[@name='acmedns']";  protocol='https'; bindingInformation='*:443:acmedns.fragt.root.local' }
            )

            Mock Use-TUACMEProdAccount   {}
            Mock Get-WebBinding          { return $script:_bindings }
            Mock Write-Host              {}
            Mock Read-Host               { '' }
            $script:_lineCall = 0
            Mock Read-LineOrEscape {
                param($Prompt)
                $script:_lineCall++
                switch ($script:_lineCall) {
                    1 { return 'all' }
                    2 { return 'n'   }
                    default { return '' }
                }
            }
            $script:_orderCalls = @()
            Mock Invoke-OrderCertificate {
                param($Domain, [string[]]$Sans)
                $script:_orderCalls += [PSCustomObject]@{
                    Domain = $Domain
                    Sans   = if ($Sans) { @($Sans) } else { @() }
                }
            }

            Invoke-IISOrderFromBindings

            $script:_orderCalls.Count | Should -Be 5
            foreach ($call in $script:_orderCalls) {
                $call.Sans.Count | Should -Be 0
            }
            ($script:_orderCalls.Domain | Sort-Object) | Should -Be @(
                'ACME01P',
                'ACME01P.fragt.root.local',
                'acmedns.fragt.root.local',
                'acmetest',
                'acmetest.fragt.root.local'
            )
        }
    }

    It "Esc on site picker cancels without calling Invoke-OrderCertificate" {
        InModuleScope TU-ACME {
            $script:_bindings = @(
                [PSCustomObject]@{ ItemXPath="/system.applicationHost/sites/site[@name='Acme']"; protocol='https'; bindingInformation='*:443:ACME01P.fragt.root.local' }
            )

            Mock Use-TUACMEProdAccount   {}
            Mock Get-WebBinding          { return $script:_bindings }
            Mock Write-Host              {}
            Mock Read-Host               { '' }
            Mock Read-LineOrEscape       { return $null }
            Mock Invoke-OrderCertificate {}

            Invoke-IISOrderFromBindings

            Assert-MockCalled Invoke-OrderCertificate -Times 0 -Scope It
        }
    }

    It 'non-FQDN hostnames are warned about but not blocked from the order' {
        # The Test-IsFqdnHostname classifier itself is covered by UC-9.12.
        # Here we guard the "warn but continue" contract: a binding fixture
        # consisting entirely of single-label hostnames still reaches
        # Invoke-OrderCertificate. The warning rendering between the two is
        # straight glue that follows from those two facts.
        InModuleScope TU-ACME {
            $script:_bindings = @(
                [PSCustomObject]@{ ItemXPath="/system.applicationHost/sites/site[@name='Acme']"; protocol='https'; bindingInformation='*:443:ACME01P' },
                [PSCustomObject]@{ ItemXPath="/system.applicationHost/sites/site[@name='Acme']"; protocol='https'; bindingInformation='*:443:ACME' }
            )

            Mock Use-TUACMEProdAccount   {}
            Mock Get-WebBinding          { return $script:_bindings }
            Mock Write-Host              {}
            Mock Read-Host               { '' }
            $script:_lineCall = 0
            Mock Read-LineOrEscape {
                param($Prompt)
                $script:_lineCall++
                switch ($script:_lineCall) {
                    1 { return 'all' }
                    2 { return 'Y'   }
                    default { return '' }
                }
            }
            Mock Invoke-OrderCertificate {}

            Invoke-IISOrderFromBindings

            Assert-MockCalled Invoke-OrderCertificate -Times 1 -Scope It
        }
    }
}
