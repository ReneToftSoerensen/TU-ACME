#Requires -Modules Pester
Describe 'Invoke-OrderCertificate against Pebble (live) - HTTP-01 / WebRoot' -Tag 'Integration' {

    BeforeAll {
        $script:RepoRoot   = Resolve-Path "$PSScriptRoot\..\.."
        $script:ModulePath = Join-Path $script:RepoRoot 'TU-ACME\TU-ACME.psd1'

        Import-Module (Join-Path $PSScriptRoot 'Pebble.psm1') -Force
        $script:PebbleProd    = Start-PebbleServer -Role Prod
        $script:PebbleStaging = Start-PebbleServer -Role Staging

        $script:OrigProgramData  = $env:ProgramData
        $script:OrigPoshAcmeHome = $env:POSHACME_HOME
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-int-http01-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null

        # WebRoot needs a directory to drop the challenge token into. Pebble
        # is configured with PEBBLE_VA_ALWAYS_VALID=1 (set in Pebble.psm1) so
        # it never actually fetches the file, but the plugin still tries to
        # write it, so the path must exist (or be creatable).
        $script:WebRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-int-http01-wr-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:WebRoot -Force | Out-Null

        Import-Module $script:ModulePath -Force

        # Initialize TU-ACME against the running Pebble pair. Drive the
        # wizard once so prod + staging accounts get created and the
        # config records both account IDs.
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

        # Pre-populate the WebRoot-plugin sidecar so Invoke-OrderCertificate
        # finds saved credentials without going through Invoke-DnsPluginConfig.
        # WebRoot.ps1 in Posh-ACME 4.32 expects:
        #   -WRPath        [string[]] mandatory - the web root directory.
        #   -WRExactPath   [switch]   write the token directly into WRPath
        #                             instead of WRPath/.well-known/acme-challenge.
        $sidecar = Join-Path $env:ProgramData 'TU-ACME\plugin-args-WebRoot.xml'
        @{ WRPath = $script:WebRoot; WRExactPath = $true } | Export-Clixml -Path $sidecar
    }

    AfterAll {
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
        if ($script:PebbleProd)    { Stop-PebbleServer $script:PebbleProd }
        if ($script:PebbleStaging) { Stop-PebbleServer $script:PebbleStaging }
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        if ($script:WebRoot -and (Test-Path $script:WebRoot)) {
            Remove-Item -Path $script:WebRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData   = $script:OrigProgramData
        $env:POSHACME_HOME = $script:OrigPoshAcmeHome
    }

    It 'issues a real cert via an HTTP-01 (WebRoot) plugin against the prod ACME account on Pebble' {
        InModuleScope TU-ACME {
            Mock Invoke-ConsoleClear  {}
            Mock Show-Spinner         { param($Message,$ScriptBlock) & $ScriptBlock }
            Mock Write-EventLogEntry  {}

            # Wizard-prompt sequence for Invoke-OrderCertificate:
            #   domain, sans (empty), plugin name, confirm (y), press-enter.
            $script:_ans = @('http01-test.example', '', 'WebRoot', 'y', '')
            $script:_idx = 0
            Mock Read-Host {
                $v = $script:_ans[$script:_idx]
                $script:_idx = $script:_idx + 1
                return $v
            }

            Invoke-OrderCertificate

            # Assert: the new cert is in the Posh-ACME store under the prod
            # account. Pebble (and other internal CAs - see memory note
            # posh-acme-internal-ca-empty-fields.md) return MainDomain=''
            # so we filter via the AllSANs collection, which is reliably
            # populated from what was passed to -Domain.
            $newCert = @(Get-PACertificate -List | Where-Object { $_.AllSANs -contains 'http01-test.example' })
            $newCert.Count             | Should -Be 1
            $newCert[0].Thumbprint     | Should -Not -BeNullOrEmpty
            $newCert[0].AllSANs        | Should -Contain 'http01-test.example'
        }
    }
}
