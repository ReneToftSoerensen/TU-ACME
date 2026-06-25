<#
    TU-ACME.Integration.Tests.ps1 - full-scale, end-to-end integration test.

    Unlike the mocked unit tests under tests/Unit, this suite talks to a *real*
    ACME server. It is designed to run against Pebble
    (https://github.com/letsencrypt/pebble), the official test ACME CA, paired
    with pebble-challtestsrv for DNS-01 validation. It:

      1. Points Posh-ACME at the test ACME directory.
      2. Creates a real ACME account.
      3. Issues a real certificate end-to-end (order -> dns-01 challenge ->
         finalize -> download) using the ChallTestSrv test plugin.
      4. Exercises the TU-ACME module's live Posh-ACME helpers against that real
         state (server resolution, context, account/order enumeration, ISO-8601
         date formatting, invalid-order detection).

    The whole suite is opt-in and self-skips unless the TUACME_ACME_DIRECTORY
    environment variable points at a reachable ACME directory URL, so the
    Windows unit-test job (which excludes the 'Integration' tag) and local
    `Invoke-Pester ./tests` runs are unaffected.

    Required environment variables when enabled:
      TUACME_ACME_DIRECTORY - ACME directory URL (e.g. https://localhost:14000/dir)
      TUACME_CHALLTESTSRV   - challtestsrv management URL (e.g. http://localhost:8055)
    POSHACME_PLUGINS must point at tests/Integration/plugins so the ChallTestSrv
    plugin is discoverable by Posh-ACME.
#>

#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeDiscovery {
    $script:IntegrationEnabled = -not [string]::IsNullOrWhiteSpace($env:TUACME_ACME_DIRECTORY)
}

Describe 'TU-ACME full-scale issuance against a test ACME server' -Tag 'Integration' -Skip:(-not $script:IntegrationEnabled) {

    BeforeAll {
        $script:DirectoryUrl = $env:TUACME_ACME_DIRECTORY
        $script:CtsMgmtUri    = if ($env:TUACME_CHALLTESTSRV) { $env:TUACME_CHALLTESTSRV } else { 'http://localhost:8055' }

        # Isolate the Posh-ACME store for this run so we never touch a developer's
        # real accounts/orders. Must be set before Posh-ACME is imported.
        $script:AcmeHome = Join-Path ([IO.Path]::GetTempPath()) ("tuacme-it-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:AcmeHome -Force | Out-Null
        $env:POSHACME_HOME = $script:AcmeHome

        # Make the ChallTestSrv test plugin discoverable by Posh-ACME.
        if ([string]::IsNullOrWhiteSpace($env:POSHACME_PLUGINS)) {
            $env:POSHACME_PLUGINS = Join-Path $PSScriptRoot 'plugins'
        }

        Import-Module Posh-ACME -Force
        $modulePath = Join-Path $PSScriptRoot '..' '..' 'src' 'TU-ACME.psd1'
        Import-Module $modulePath -Force

        # A unique apex so re-runs never collide on a cached order/identifier.
        $script:Domain = ('tuacme-{0}.example.com' -f ([guid]::NewGuid().ToString('N').Substring(0, 8)))

        # Activate the test ACME server. Resolve-PAServerArg is exercised
        # separately below; here we use the raw directory URL plus
        # -SkipCertificateCheck for Pebble's self-signed cert.
        Set-PAServer -DirectoryUrl $script:DirectoryUrl -SkipCertificateCheck | Out-Null

        New-PAAccount -Contact 'tuacme-integration@example.com' -AcceptTOS -Force | Out-Null

        $script:Cert = New-PACertificate -Domain $script:Domain `
            -Plugin ChallTestSrv `
            -PluginArgs @{ CTSMgmtUri = $script:CtsMgmtUri } `
            -AcceptTOS -Force -DnsSleep 5 -ValidationTimeout 90
    }

    AfterAll {
        if ($script:AcmeHome -and (Test-Path $script:AcmeHome)) {
            Remove-Item -Path $script:AcmeHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Certificate issuance' {
        It 'returns a PACertificate with a thumbprint' {
            $script:Cert | Should -Not -BeNullOrEmpty
            $script:Cert.Thumbprint | Should -Match '^[0-9A-Fa-f]{40}$'
        }

        It 'covers the requested identifier' {
            $script:Cert.AllSANs | Should -Contain $script:Domain
        }

        It 'has a future expiry' {
            ([datetime]$script:Cert.NotAfter) | Should -BeGreaterThan (Get-Date)
        }

        It 'wrote the order into the Posh-ACME store' {
            $order = Get-PAOrder -MainDomain $script:Domain
            $order | Should -Not -BeNullOrEmpty
            $order.status | Should -Be 'valid'
        }
    }

    Context 'TU-ACME helpers against live ACME state' {
        It 'Resolve-PAServerArg passes the directory URL through unchanged' {
            InModuleScope TU-ACME -Parameters @{ Url = $script:DirectoryUrl } {
                param($Url)
                Resolve-PAServerArg -ServerInput $Url | Should -Be $Url
            }
        }

        It 'Get-CurrentPAContext returns the active server and account' {
            InModuleScope TU-ACME {
                $ctx = Get-CurrentPAContext
                $ctx.Server  | Should -Not -BeNullOrEmpty
                $ctx.Account | Should -Not -BeNullOrEmpty
            }
        }

        It 'Get-AllPAAccounts enumerates the created account' {
            InModuleScope TU-ACME {
                $accounts = Get-AllPAAccounts
                @($accounts).Count | Should -BeGreaterThan 0
                ($accounts | Where-Object { $_.Contact -match 'tuacme-integration@example.com' }) |
                    Should -Not -BeNullOrEmpty
            }
        }

        It 'Get-PAOrdersList includes the issued order with a normalized identifier' {
            InModuleScope TU-ACME -Parameters @{ Domain = $script:Domain } {
                param($Domain)
                $orders = Get-PAOrdersList
                $match  = $orders | Where-Object { $_.Identifiers -split ',' -contains $Domain }
                $match | Should -Not -BeNullOrEmpty
                $match.Status | Should -Be 'valid'
                $match.CertThumb | Should -Match '^[0-9A-Fa-f]{40}$'
            }
        }

        It 'Format-PADate renders the live order NotAfter as ISO-8601' {
            InModuleScope TU-ACME -Parameters @{ Domain = $script:Domain } {
                param($Domain)
                $orders = Get-PAOrdersList
                $match  = $orders | Where-Object { $_.Identifiers -split ',' -contains $Domain } | Select-Object -First 1
                Format-PADate $match.NotAfter | Should -Match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$'
            }
        }

        It 'Get-PAInvalidOrdersForIdentifiers reports no invalid order for the valid identifier' {
            InModuleScope TU-ACME -Parameters @{ Domain = $script:Domain } {
                param($Domain)
                @(Get-PAInvalidOrdersForIdentifiers -Identifiers @($Domain)).Count | Should -Be 0
            }
        }
    }
}
