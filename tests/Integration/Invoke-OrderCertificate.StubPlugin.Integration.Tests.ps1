#Requires -Modules Pester
Describe 'Invoke-OrderCertificate against Pebble with a no-op dns-01 stub plugin (live)' -Tag 'Integration' {

    BeforeAll {
        $script:RepoRoot   = Resolve-Path "$PSScriptRoot\..\.."
        $script:ModulePath = Join-Path $script:RepoRoot 'TU-ACME\TU-ACME.psd1'

        Import-Module (Join-Path $PSScriptRoot 'Pebble.psm1') -Force
        $script:PebbleProd    = Start-PebbleServer -Role Prod
        $script:PebbleStaging = Start-PebbleServer -Role Staging

        # Locate the Posh-ACME module's Plugins folder. Posh-ACME enumerates
        # plugins by globbing this directory at module-load time
        # (Private/Import-PluginDetail.ps1), so a freshly-installed plugin
        # only becomes visible after a force-reimport of Posh-ACME.
        $paModule = Get-Module Posh-ACME -ListAvailable |
                    Sort-Object Version -Descending |
                    Select-Object -First 1
        if (-not $paModule) { throw 'Posh-ACME is not installed on this host.' }
        $script:PoshAcmePluginsDir = Join-Path $paModule.ModuleBase 'Plugins'
        if (-not (Test-Path $script:PoshAcmePluginsDir)) {
            throw "Posh-ACME plugins dir not found at $script:PoshAcmePluginsDir."
        }

        # Install the TUACMETestStub stub into Posh-ACME's Plugins/ dir
        # BEFORE TU-ACME is imported. TU-ACME's module load does an
        # "Import-Module Posh-ACME -Force" which re-runs Posh-ACME's
        # plugin enumerator (Private/Import-PluginDetail.ps1) - that's
        # what makes the stub visible to Get-PAPlugin without an explicit
        # second reimport. Track the installed path so AfterAll can
        # delete it cleanly.
        $script:StubSource = Join-Path $script:RepoRoot 'tests\Fixtures\TUACMETestStub.ps1'
        if (-not (Test-Path $script:StubSource)) {
            throw "Stub plugin source not found at $script:StubSource."
        }
        $script:StubInstalled = Join-Path $script:PoshAcmePluginsDir 'TUACMETestStub.ps1'
        Copy-Item -Path $script:StubSource -Destination $script:StubInstalled -Force

        # Sandbox the TU-ACME config + Posh-ACME store before any module
        # import so POSHACME_HOME resolves under the throwaway path that
        # TU-ACME's own Initialize-TUACMEStore derives from $env:ProgramData.
        $script:OrigProgramData  = $env:ProgramData
        $script:OrigPoshAcmeHome = $env:POSHACME_HOME
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-int-stub-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null

        # Drop any pre-loaded Posh-ACME so TU-ACME's load triggers a fresh
        # Import-PluginDetail pass that picks up the stub.
        Remove-Module Posh-ACME -Force -ErrorAction SilentlyContinue
        Import-Module $script:ModulePath -Force

        # Drive the wizard once so the prod + staging accounts get created
        # and the config records both account IDs.
        $prodUrl    = $script:PebbleProd.DirectoryUrl
        $stagingUrl = $script:PebbleStaging.DirectoryUrl
        InModuleScope TU-ACME -Parameters @{ ProdUrl = $prodUrl; StagingUrl = $stagingUrl } {
            param($ProdUrl, $StagingUrl)
            Mock Invoke-ConsoleClear  {}
            Mock Show-Spinner         { param($Message,$ScriptBlock) & $ScriptBlock }
            Mock Write-EventLogEntry  {}
            $script:_initAns = @($ProdUrl, $StagingUrl, 'ops@example.com', 'y')
            $script:_initIdx = 0
            Mock Read-Host {
                $v = $script:_initAns[$script:_initIdx]
                $script:_initIdx = $script:_initIdx + 1
                return $v
            }
            Initialize-TUACMEEnvironment
        }

        # Pre-write the sidecar so Invoke-OrderCertificate finds saved
        # plugin args for TUACMETestStub. The stub accepts a single
        # -Dummy parameter so any non-empty hashtable passes validation.
        $script:Sidecar = Join-Path $env:ProgramData 'TU-ACME\plugin-args-TUACMETestStub.xml'
        @{ Dummy = 'x' } | Export-Clixml -Path $script:Sidecar
    }

    AfterAll {
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue

        if ($script:PebbleProd)    { Stop-PebbleServer $script:PebbleProd }
        if ($script:PebbleStaging) { Stop-PebbleServer $script:PebbleStaging }

        # Remove the stub plugin from Posh-ACME's Plugins/ dir and drop
        # the loaded Posh-ACME module so subsequent tests get a clean
        # plugin enumeration on their next import.
        if ($script:StubInstalled -and (Test-Path $script:StubInstalled)) {
            Remove-Item -LiteralPath $script:StubInstalled -Force -ErrorAction SilentlyContinue
        }
        Remove-Module Posh-ACME -Force -ErrorAction SilentlyContinue

        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData   = $script:OrigProgramData
        $env:POSHACME_HOME = $script:OrigPoshAcmeHome
    }

    It 'issues a prod cert end-to-end via the installed TUACMETestStub plugin' {
        InModuleScope TU-ACME {
            Mock Invoke-ConsoleClear  {}
            Mock Show-Spinner         { param($Message,$ScriptBlock) & $ScriptBlock }
            Mock Write-EventLogEntry  {}

            # Wizard-prompt sequence for Invoke-OrderCertificate:
            #   domain, sans (empty), plugin name, confirm (y), press-enter.
            $script:_ans = @('stub-test.example', '', 'TUACMETestStub', 'y', '')
            $script:_idx = 0
            Mock Read-Host {
                $v = $script:_ans[$script:_idx]
                $script:_idx = $script:_idx + 1
                return $v
            }

            Invoke-OrderCertificate

            # Assert: the cert landed in the Posh-ACME store. Pebble (and
            # other internal CAs) return MainDomain='' so we filter via
            # AllSANs, which is reliably populated from -Domain.
            $newCert = @(Get-PACertificate -List | Where-Object { $_.AllSANs -contains 'stub-test.example' })
            $newCert.Count         | Should -Be 1
            $newCert[0].Thumbprint | Should -Not -BeNullOrEmpty
            $newCert[0].AllSANs    | Should -Contain 'stub-test.example'
        }
    }
}
