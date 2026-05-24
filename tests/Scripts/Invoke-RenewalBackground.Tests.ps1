#Requires -Modules Pester
Describe 'TU-ACME renewal background script' -Tag 'Scripts' {
    BeforeAll {
        $script:RepoRoot   = Resolve-Path "$PSScriptRoot\..\.."
        $script:ScriptPath = Join-Path $script:RepoRoot 'TU-ACME\Scripts\Invoke-RenewalBackground.ps1'
        $script:ModulePath = Join-Path $script:RepoRoot 'TU-ACME\TU-ACME.psd1'
        Import-Module $script:ModulePath -Force
    }
    AfterAll {
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'UC-8.06: calls Use-TUACMEProdAccount before Submit-Renewal' {
        InModuleScope TU-ACME -Parameters @{ Path = $script:ScriptPath } {
            param($Path)

            # Stub Posh-ACME cmdlets the script depends on.
            function Submit-Renewal { param([switch]$AllAccounts, $ErrorAction) }

            # Use $global: so the mock bodies (executed in the module's
            # script scope) and the assertions (Pester test scope) share
            # the same call-order trail.
            $global:_uc806_order = @()
            Mock Import-Module         {}
            Mock Use-TUACMEProdAccount { $global:_uc806_order += 'UseProd' }
            Mock Submit-Renewal        { $global:_uc806_order += 'Submit' }
            Mock Get-PACertificate     { @() }
            Mock Write-EventLogEntry   {}

            & $Path -Foreground

            Assert-MockCalled Use-TUACMEProdAccount -Times 1 -Scope It
            Assert-MockCalled Submit-Renewal        -Times 1 -Scope It
            $global:_uc806_order[0] | Should -Be 'UseProd'
            $global:_uc806_order[1] | Should -Be 'Submit'
            Remove-Variable -Name _uc806_order -Scope Global -ErrorAction SilentlyContinue
        }
    }

    It 'UC-8.07: emits Event 1001 when a cert thumbprint changes' {
        InModuleScope TU-ACME -Parameters @{ Path = $script:ScriptPath } {
            param($Path)

            function Submit-Renewal { param([switch]$AllAccounts, $ErrorAction) }

            $global:_uc807_phase = 0
            Mock Import-Module         {}
            Mock Use-TUACMEProdAccount {}
            Mock Submit-Renewal        { $global:_uc807_phase = 1 }
            Mock Write-EventLogEntry   {}
            Mock Get-PACertificate     {
                if ($global:_uc807_phase -eq 0) {
                    @([PSCustomObject]@{ Subject = 'CN=foo.example'; Thumbprint = 'OLD1' })
                } else {
                    @([PSCustomObject]@{ Subject = 'CN=foo.example'; Thumbprint = 'NEW1' })
                }
            }

            & $Path -Foreground

            Assert-MockCalled Write-EventLogEntry -Times 1 -Scope It -ParameterFilter {
                $EventId -eq 1001 -and
                $Message -match 'foo\.example' -and
                $Message -match 'OLD1' -and
                $Message -match 'NEW1'
            }
            Remove-Variable -Name _uc807_phase -Scope Global -ErrorAction SilentlyContinue
        }
    }

    It 'UC-8.08: invokes Update-IISBindingForCert when the helper exists' {
        InModuleScope TU-ACME -Parameters @{ Path = $script:ScriptPath } {
            param($Path)

            function Submit-Renewal           { param([switch]$AllAccounts, $ErrorAction) }
            function Update-IISBindingForCert { param($OldThumbprint, $NewThumbprint) }

            $global:_uc808_phase = 0
            Mock Import-Module            {}
            Mock Use-TUACMEProdAccount    {}
            Mock Submit-Renewal           { $global:_uc808_phase = 1 }
            Mock Write-EventLogEntry      {}
            Mock Update-IISBindingForCert {}
            Mock Get-PACertificate        {
                if ($global:_uc808_phase -eq 0) {
                    @([PSCustomObject]@{ Subject = 'CN=bar.example'; Thumbprint = 'OLD2' })
                } else {
                    @([PSCustomObject]@{ Subject = 'CN=bar.example'; Thumbprint = 'NEW2' })
                }
            }

            & $Path -Foreground

            Assert-MockCalled Update-IISBindingForCert -Times 1 -Scope It -ParameterFilter {
                $OldThumbprint -eq 'OLD2' -and $NewThumbprint -eq 'NEW2'
            }
            Remove-Variable -Name _uc808_phase -Scope Global -ErrorAction SilentlyContinue
        }
    }
}
