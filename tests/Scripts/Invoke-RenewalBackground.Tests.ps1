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
            # Non-empty cert list: UC-8.10 makes the script short-circuit
            # before Submit-Renewal when Get-PACertificate -List returns
            # @(), so this UC has to feed it at least one cert to exercise
            # the use-prod-then-submit ordering it's asserting on.
            Mock Get-PACertificate     { @([PSCustomObject]@{ MainDomain = 'uc806.example'; Thumbprint = 'T1' }) }
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
                    @([PSCustomObject]@{ MainDomain = 'foo.example'; Thumbprint = 'OLD1' })
                } else {
                    @([PSCustomObject]@{ MainDomain = 'foo.example'; Thumbprint = 'NEW1' })
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

    It 'UC-8.09: does not -Force re-import the running TU-ACME module' {
        # Regression: the script previously called `Import-Module TU-ACME -Force`
        # at the top, which tore down and rebuilt the module object that was
        # currently executing whenever the renewal was invoked from the
        # Automation menu's "Run renewal now (foreground)" entry. Once the
        # in-flight module instance was replaced, the calling function's
        # private symbols (Show-Menu, Wait-AnyKey, ...) went out of scope and
        # the very next loop iteration blew up with "term 'Show-Menu' is not
        # recognized". The body now lives inside `& $module { ... }`, so a
        # -Force re-import must never happen on the renewal hot path.
        InModuleScope TU-ACME -Parameters @{ Path = $script:ScriptPath } {
            param($Path)

            function Submit-Renewal { param([switch]$AllAccounts, $ErrorAction) }

            $global:_uc809_forceCount  = 0
            $global:_uc809_importCount = 0
            Mock Import-Module {
                param($Name, [switch]$Force)
                $global:_uc809_importCount++
                if ($Force) { $global:_uc809_forceCount++ }
            }
            Mock Use-TUACMEProdAccount {}
            Mock Submit-Renewal        {}
            Mock Get-PACertificate     { @() }
            Mock Write-EventLogEntry   {}

            & $Path -Foreground

            # The module is already loaded in BeforeAll, so the script must
            # short-circuit the Import-Module branch entirely — neither a
            # plain import nor (especially) a -Force import.
            $global:_uc809_forceCount  | Should -Be 0
            $global:_uc809_importCount | Should -Be 0
            Remove-Variable -Name _uc809_forceCount  -Scope Global -ErrorAction SilentlyContinue
            Remove-Variable -Name _uc809_importCount -Scope Global -ErrorAction SilentlyContinue
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
                    @([PSCustomObject]@{ MainDomain = 'bar.example'; Thumbprint = 'OLD2' })
                } else {
                    @([PSCustomObject]@{ MainDomain = 'bar.example'; Thumbprint = 'NEW2' })
                }
            }

            & $Path -Foreground

            Assert-MockCalled Update-IISBindingForCert -Times 1 -Scope It -ParameterFilter {
                $OldThumbprint -eq 'OLD2' -and $NewThumbprint -eq 'NEW2'
            }
            Remove-Variable -Name _uc808_phase -Scope Global -ErrorAction SilentlyContinue
        }
    }

    It 'UC-8.10: no-certs case is benign — Event 1001, never 3001, no Submit-Renewal' {
        # Regression: when Get-PACertificate -List was empty, the old
        # script still called Submit-Renewal, which Posh-ACME implements
        # via `throw "No order found for the specified parameters."`.
        # That terminating error couldn't be suppressed with
        # -ErrorAction Continue (Stop-priority + module-internal throw),
        # so the outer catch wrote bogus Event 3001 and triggered a
        # "renewal FAILED" mail for what was really nothing-to-do.
        InModuleScope TU-ACME -Parameters @{ Path = $script:ScriptPath } {
            param($Path)

            function Submit-Renewal { param([switch]$AllAccounts, $ErrorAction) }

            Mock Import-Module         {}
            Mock Use-TUACMEProdAccount {}
            Mock Get-PACertificate     { @() }
            Mock Submit-Renewal        {}
            Mock Send-TUACMEMail       { $true }
            Mock Get-TUACMEConfig      { [PSCustomObject]@{ Email = [PSCustomObject]@{ SmtpServer = 'smtp.example' } } }
            Mock Write-EventLogEntry   {}

            & $Path -Foreground

            Assert-MockCalled Submit-Renewal -Times 0 -Scope It
            Assert-MockCalled Send-TUACMEMail -Times 0 -Scope It
            Assert-MockCalled Write-EventLogEntry -Times 1 -Scope It -ParameterFilter {
                $EventId -eq 1001 -and $Message -match 'no certs to renew'
            }
            Assert-MockCalled Write-EventLogEntry -Times 0 -Scope It -ParameterFilter {
                $EventId -eq 3001
            }
        }
    }

    It 'UC-8.11: renewal FAILED mail body includes host, RunAs, ACME directory, message, and stack trace' {
        InModuleScope TU-ACME -Parameters @{ Path = $script:ScriptPath } {
            param($Path)

            function Submit-Renewal { param([switch]$AllAccounts, $ErrorAction) }
            function Get-PAServer   { param([switch]$ErrorAction) }

            Mock Import-Module         {}
            Mock Use-TUACMEProdAccount {}
            Mock Get-PACertificate     { @([PSCustomObject]@{ MainDomain = 'fail.example'; Thumbprint = 'T1' }) }
            Mock Submit-Renewal        { throw 'Posh-ACME: connection refused' }
            Mock Get-PAServer          { [PSCustomObject]@{ location = 'https://acme.internal.example/directory' } }
            Mock Get-TUACMEConfig      {
                [PSCustomObject]@{
                    Email = [PSCustomObject]@{ SmtpServer = 'smtp.example' }
                }
            }
            Mock Write-EventLogEntry   {}

            $global:_uc811_subject = $null
            $global:_uc811_body    = $null
            Mock Send-TUACMEMail {
                param($Subject, $Body)
                $global:_uc811_subject = $Subject
                $global:_uc811_body    = $Body
                $true
            }

            # Foreground re-throws after the catch handler runs; swallow
            # so the test can inspect what the catch built.
            try { & $Path -Foreground } catch {}

            $global:_uc811_subject | Should -Match '^TU-ACME renewal FAILED on \S+'
            $global:_uc811_body    | Should -Match '(?m)^Host\s+:\s*\S'
            $global:_uc811_body    | Should -Match '(?m)^RunAs\s+:\s*\S'
            $global:_uc811_body    | Should -Match '(?m)^ACME directory\s+:\s*https://acme\.internal\.example/directory'
            $global:_uc811_body    | Should -Match 'connection refused'
            $global:_uc811_body    | Should -Match '(?ms)stack trace'

            Remove-Variable -Name _uc811_subject -Scope Global -ErrorAction SilentlyContinue
            Remove-Variable -Name _uc811_body    -Scope Global -ErrorAction SilentlyContinue
        }
    }
}
