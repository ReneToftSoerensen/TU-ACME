#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' 'src' 'TU-ACME.psd1'
    Import-Module $modulePath -Force

    # On non-Windows CI the Posh-ACME module is not installed, so define guarded
    # stubs for the cmdlets the tested functions call, allowing Mock to target them.
    if (-not (Get-Command Get-PAServer -ErrorAction SilentlyContinue)) {
        function global:Get-PAServer { [CmdletBinding()] param([switch]$List) }
    }
    # Stubs for the Posh-ACME cmdlets the renewal orchestrator activates/calls, so
    # Mock can target them on non-Windows runners where Posh-ACME is absent.
    if (-not (Get-Command Set-PAServer -ErrorAction SilentlyContinue)) {
        function global:Set-PAServer { [CmdletBinding()] param([Parameter(ValueFromRemainingArguments)]$Args) }
    }
    if (-not (Get-Command Set-PAAccount -ErrorAction SilentlyContinue)) {
        function global:Set-PAAccount { [CmdletBinding()] param([string]$ID, [switch]$UseAltPluginEncryption) }
    }
    if (-not (Get-Command Get-PAOrder -ErrorAction SilentlyContinue)) {
        function global:Get-PAOrder { [CmdletBinding()] param([switch]$List, [switch]$Refresh, [string]$Name) }
    }
    if (-not (Get-Command Submit-Renewal -ErrorAction SilentlyContinue)) {
        function global:Submit-Renewal { [CmdletBinding()] param([switch]$AllOrders, [switch]$Force) }
    }
}

Describe 'Get-OrderedIdentifiers' {
    It 'places the common name first' {
        InModuleScope TU-ACME {
            $r = Get-OrderedIdentifiers -CommonName 'cn.example.com' -Hosts @('b.example.com', 'cn.example.com', 'a.example.com')
            $r[0] | Should -Be 'cn.example.com'
        }
    }

    It 'sorts the remaining hosts and excludes the CN from the tail' {
        InModuleScope TU-ACME {
            $r = Get-OrderedIdentifiers -CommonName 'cn.example.com' -Hosts @('b.example.com', 'cn.example.com', 'a.example.com')
            $r | Should -Be @('cn.example.com', 'a.example.com', 'b.example.com')
        }
    }

    It 'returns just the CN when it is the only host' {
        InModuleScope TU-ACME {
            (Get-OrderedIdentifiers -CommonName 'only.example.com' -Hosts @('only.example.com')) |
                Should -Be @('only.example.com')
        }
    }
}

Describe 'Test-WacsHostPattern' {
    It 'matches a literal host' {
        InModuleScope TU-ACME {
            Test-WacsHostPattern -Value 'www.example.com' -Patterns @('www.example.com') | Should -BeTrue
        }
    }

    It 'matches a * wildcard' {
        InModuleScope TU-ACME {
            Test-WacsHostPattern -Value 'api.example.com' -Patterns @('*.example.com') | Should -BeTrue
        }
    }

    It 'matches a ? single character' {
        InModuleScope TU-ACME {
            Test-WacsHostPattern -Value 'a.example.com' -Patterns @('?.example.com') | Should -BeTrue
        }
    }

    It 'does not match a non-matching host' {
        InModuleScope TU-ACME {
            Test-WacsHostPattern -Value 'www.other.org' -Patterns @('*.example.com') | Should -BeFalse
        }
    }
}

Describe 'ConvertTo-ThumbprintBytes' {
    It 'round-trips a thumbprint through bytes' {
        InModuleScope TU-ACME {
            $thumb = 'AABBCCDDEEFF00112233445566778899AABBCCDD'
            $bytes = ConvertTo-ThumbprintBytes -Thumbprint $thumb
            $bytes.Length | Should -Be 20
            ([BitConverter]::ToString($bytes)).Replace('-', '') | Should -Be $thumb
        }
    }
}

Describe 'Resolve-PAServerArg' {
    It 'passes a built-in alias through unchanged' {
        InModuleScope TU-ACME {
            Resolve-PAServerArg -ServerInput 'LE_PROD' | Should -Be 'LE_PROD'
        }
    }

    It 'passes an https URL through unchanged' {
        InModuleScope TU-ACME {
            Resolve-PAServerArg -ServerInput 'https://acme.example.com/directory' |
                Should -Be 'https://acme.example.com/directory'
        }
    }

    It 'resolves a custom short name to its directory URL' {
        InModuleScope TU-ACME {
            Mock Get-PAServer { @([pscustomobject]@{ Name = 'internal'; location = 'https://acme.internal/dir' }) }
            Resolve-PAServerArg -ServerInput 'internal' | Should -Be 'https://acme.internal/dir'
        }
    }
}

Describe 'ConvertTo-DateTime / Format-PADate' {
    It 'returns a DateTime unchanged' {
        InModuleScope TU-ACME {
            $dt = [datetime]'2026-01-02T03:04:05'
            (ConvertTo-DateTime $dt) | Should -Be $dt
        }
    }

    It 'parses an ISO-8601 string' {
        InModuleScope TU-ACME {
            (ConvertTo-DateTime '2026-01-02T03:04:05').Year | Should -Be 2026
        }
    }

    It 'returns $null for empty input' {
        InModuleScope TU-ACME {
            ConvertTo-DateTime '' | Should -BeNullOrEmpty
        }
    }

    It 'formats a DateTime as ISO-8601 yyyy-MM-dd HH:mm' {
        InModuleScope TU-ACME {
            Format-PADate ([datetime]'2026-01-02T03:04:00') | Should -Be '2026-01-02 03:04'
        }
    }

    It 'formats an ISO-8601 string input' {
        InModuleScope TU-ACME {
            Format-PADate '2026-01-02T03:04:00' | Should -Be '2026-01-02 03:04'
        }
    }

    It 'returns - for unparseable input' {
        InModuleScope TU-ACME {
            Format-PADate 'not-a-date' | Should -Be '-'
        }
    }
}

Describe 'Get-PAInvalidOrdersForIdentifiers' {
    It 'returns only invalid orders overlapping the requested identifiers' {
        InModuleScope TU-ACME {
            Mock Get-PAOrdersList {
                @(
                    [pscustomobject]@{ Name = 'o1'; Identifiers = 'a.example.com,b.example.com'; Status = 'invalid' },
                    [pscustomobject]@{ Name = 'o2'; Identifiers = 'c.example.com'; Status = 'valid' },
                    [pscustomobject]@{ Name = 'o3'; Identifiers = 'x.example.com'; Status = 'invalid' }
                )
            }
            $r = Get-PAInvalidOrdersForIdentifiers -Identifiers @('a.example.com')
            $r.Count | Should -Be 1
            $r[0].Name | Should -Be 'o1'
        }
    }

    It 'returns nothing when no invalid order overlaps' {
        InModuleScope TU-ACME {
            Mock Get-PAOrdersList {
                @([pscustomobject]@{ Name = 'o1'; Identifiers = 'a.example.com'; Status = 'valid' })
            }
            @(Get-PAInvalidOrdersForIdentifiers -Identifiers @('a.example.com')).Count | Should -Be 0
        }
    }
}

Describe 'Resolve-TUACMERenewalTargets' {
    BeforeEach {
        $script:fakeAccounts = @(
            [pscustomobject]@{ ServerName = 'srvA'; ServerArg = 'https://a/dir'; ServerLoc = 'https://a/dir'; AccountID = 'acc1' },
            [pscustomobject]@{ ServerName = 'srvB'; ServerArg = 'https://b/dir'; ServerLoc = 'https://b/dir'; AccountID = 'acc2' },
            [pscustomobject]@{ ServerName = 'srvC'; ServerArg = 'https://c/dir'; ServerLoc = 'https://c/dir'; AccountID = 'acc2' }
        )
    }

    It 'returns all tuples when no filters are given' {
        InModuleScope TU-ACME -Parameters @{ accounts = $script:fakeAccounts } {
            param($accounts)
            Mock Get-AllPAAccounts { $accounts }
            $r = Resolve-TUACMERenewalTargets
            $r.Status | Should -Be 'ok'
            $r.Targets.Count | Should -Be 3
        }
    }

    It 'infers the server from a unique AccountID (convenience fallback)' {
        InModuleScope TU-ACME -Parameters @{ accounts = $script:fakeAccounts } {
            param($accounts)
            Mock Get-AllPAAccounts { $accounts }
            $r = Resolve-TUACMERenewalTargets -AccountID 'acc1'
            $r.Status | Should -Be 'ok'
            $r.Targets.Count | Should -Be 1
            $r.Targets[0].ServerName | Should -Be 'srvA'
            $r.Message | Should -Match "Inferred server 'srvA'"
        }
    }

    It 'reports notfound (status) for an unknown AccountID' {
        InModuleScope TU-ACME -Parameters @{ accounts = $script:fakeAccounts } {
            param($accounts)
            Mock Get-AllPAAccounts { $accounts }
            $r = Resolve-TUACMERenewalTargets -AccountID 'nope'
            $r.Status | Should -Be 'notfound'
            $r.Targets.Count | Should -Be 0
        }
    }

    It 'reports ambiguous when an AccountID exists on multiple servers' {
        InModuleScope TU-ACME -Parameters @{ accounts = $script:fakeAccounts } {
            param($accounts)
            Mock Get-AllPAAccounts { $accounts }
            $r = Resolve-TUACMERenewalTargets -AccountID 'acc2'
            $r.Status | Should -Be 'ambiguous'
            $r.Message | Should -Match 'disambiguate with -ServerName'
        }
    }

    It 'filters by ServerName + AccountID together' {
        InModuleScope TU-ACME -Parameters @{ accounts = $script:fakeAccounts } {
            param($accounts)
            Mock Get-AllPAAccounts { $accounts }
            $r = Resolve-TUACMERenewalTargets -ServerName 'srvC' -AccountID 'acc2'
            $r.Status | Should -Be 'ok'
            $r.Targets.Count | Should -Be 1
            $r.Targets[0].ServerName | Should -Be 'srvC'
        }
    }

    It 'returns none when no accounts exist at all' {
        InModuleScope TU-ACME {
            Mock Get-AllPAAccounts { @() }
            (Resolve-TUACMERenewalTargets).Status | Should -Be 'none'
        }
    }
}

Describe 'Invoke-TUACMERenewal' {
    BeforeEach {
        $script:oneAccount = @([pscustomobject]@{
            ServerName = 'srvA'; ServerArg = 'https://a/dir'; ServerLoc = 'https://a/dir'; AccountID = 'acc1'
        })
    }

    It 'is a no-op (exit 0) when nothing is due' {
        InModuleScope TU-ACME -Parameters @{ accounts = $script:oneAccount } {
            param($accounts)
            Mock Write-TUACMELog {}
            Mock Write-TUACMEEventLog {}
            Mock Get-AllPAAccounts { $accounts }
            Mock Set-PAServer {}
            Mock Set-PAAccount {}
            Mock Get-IISSslBindings { @() }
            Mock Submit-Renewal { @() }
            Mock Install-TUACMECertificate {}
            Mock Update-IISCertificateBinding {}

            Invoke-TUACMERenewal | Should -Be 0
            Should -Invoke Install-TUACMECertificate -Times 0
        }
    }

    It 'installs and SAN-rebinds a renewed cert (exit 0)' {
        InModuleScope TU-ACME -Parameters @{ accounts = $script:oneAccount } {
            param($accounts)
            Mock Write-TUACMELog {}
            Mock Write-TUACMEEventLog {}
            Mock Get-AllPAAccounts { $accounts }
            Mock Set-PAServer {}
            Mock Set-PAAccount {}
            Mock Get-IISSslBindings { @([pscustomobject]@{ HostHeader = 'www.example.com'; Thumbprint = 'OLD' }) }
            Mock Submit-Renewal { @([pscustomobject]@{ Thumbprint = 'NEW'; AllSANs = @('www.example.com'); MainDomain = 'www.example.com'; Subject = 'CN=www.example.com' }) }
            Mock Install-TUACMECertificate {}
            Mock Update-IISCertificateBinding { [pscustomobject]@{ Rebound = 1; Failed = 0; Targets = 1 } }

            Invoke-TUACMERenewal | Should -Be 0
            Should -Invoke Install-TUACMECertificate -Times 1
            Should -Invoke Update-IISCertificateBinding -Times 1 -ParameterFilter {
                $Thumbprint -eq 'NEW' -and $OldThumbprint -eq 'OLD'
            }
        }
    }

    It 'returns exit 1 when a rebind fails (partial)' {
        InModuleScope TU-ACME -Parameters @{ accounts = $script:oneAccount } {
            param($accounts)
            Mock Write-TUACMELog {}
            Mock Write-TUACMEEventLog {}
            Mock Get-AllPAAccounts { $accounts }
            Mock Set-PAServer {}
            Mock Set-PAAccount {}
            Mock Get-IISSslBindings { @() }
            Mock Submit-Renewal { @([pscustomobject]@{ Thumbprint = 'NEW'; AllSANs = @('www.example.com'); MainDomain = 'www.example.com'; Subject = 'CN=www.example.com' }) }
            Mock Install-TUACMECertificate {}
            Mock Update-IISCertificateBinding { [pscustomobject]@{ Rebound = 0; Failed = 1; Targets = 1 } }

            Invoke-TUACMERenewal | Should -Be 1
        }
    }

    It 'emits a portable-encryption remediation message on a decrypt failure (exit 1)' {
        InModuleScope TU-ACME -Parameters @{ accounts = $script:oneAccount } {
            param($accounts)
            $script:logged = [System.Collections.Generic.List[string]]::new()
            Mock Write-TUACMELog { $script:logged.Add($Message) }
            Mock Write-TUACMEEventLog {}
            Mock Get-AllPAAccounts { $accounts }
            Mock Set-PAServer {}
            Mock Set-PAAccount {}
            Mock Get-IISSslBindings { @() }
            Mock Submit-Renewal { throw 'Error occurred while decoding OAEP padding.' }
            Mock Install-TUACMECertificate {}
            Mock Update-IISCertificateBinding {}

            Invoke-TUACMERenewal | Should -Be 1
            ($script:logged -join "`n") | Should -Match 'portable encryption'
            Should -Invoke Install-TUACMECertificate -Times 0
        }
    }

    It 'returns exit 2 when there are no accounts' {
        InModuleScope TU-ACME {
            Mock Write-TUACMELog {}
            Mock Write-TUACMEEventLog {}
            Mock Get-AllPAAccounts { @() }
            Invoke-TUACMERenewal | Should -Be 2
        }
    }

    It 'returns exit 2 for an ambiguous AccountID without ServerName' {
        InModuleScope TU-ACME {
            Mock Write-TUACMELog {}
            Mock Write-TUACMEEventLog {}
            Mock Get-AllPAAccounts {
                @(
                    [pscustomobject]@{ ServerName = 'srvB'; ServerArg = 'b'; ServerLoc = 'b'; AccountID = 'dup' },
                    [pscustomobject]@{ ServerName = 'srvC'; ServerArg = 'c'; ServerLoc = 'c'; AccountID = 'dup' }
                )
            }
            Invoke-TUACMERenewal -AccountID 'dup' | Should -Be 2
        }
    }

    It 'does not renew under -WhatIf' {
        InModuleScope TU-ACME -Parameters @{ accounts = $script:oneAccount } {
            param($accounts)
            Mock Write-TUACMELog {}
            Mock Write-TUACMEEventLog {}
            Mock Get-AllPAAccounts { $accounts }
            Mock Set-PAServer {}
            Mock Set-PAAccount {}
            Mock Get-IISSslBindings { @() }
            Mock Submit-Renewal {}
            Mock Install-TUACMECertificate {}
            Mock Update-IISCertificateBinding {}

            Invoke-TUACMERenewal -WhatIf | Should -Be 0
            Should -Invoke Submit-Renewal -Times 0
        }
    }

    It 'refreshes order state when -NoCache is set' {
        InModuleScope TU-ACME -Parameters @{ accounts = $script:oneAccount } {
            param($accounts)
            Mock Write-TUACMELog {}
            Mock Write-TUACMEEventLog {}
            Mock Get-AllPAAccounts { $accounts }
            Mock Set-PAServer {}
            Mock Set-PAAccount {}
            Mock Get-IISSslBindings { @() }
            Mock Get-PAOrder { @() }
            Mock Submit-Renewal { @() }
            Mock Install-TUACMECertificate {}
            Mock Update-IISCertificateBinding {}

            Invoke-TUACMERenewal -NoCache | Should -Be 0
            Should -Invoke Get-PAOrder -Times 1 -ParameterFilter { $Refresh -eq $true }
        }
    }
}
