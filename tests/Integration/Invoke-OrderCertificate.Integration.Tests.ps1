#Requires -Modules Pester
Describe 'Invoke-OrderCertificate against Pebble (live)' -Tag 'Integration' {

    BeforeAll {
        $script:RepoRoot   = Resolve-Path "$PSScriptRoot\..\.."
        $script:ModulePath = Join-Path $script:RepoRoot 'TU-ACME\TU-ACME.psd1'

        Import-Module (Join-Path $PSScriptRoot 'Pebble.psm1') -Force
        $script:PebbleProd    = Start-PebbleServer -Role Prod
        $script:PebbleStaging = Start-PebbleServer -Role Staging

        $script:OrigProgramData  = $env:ProgramData
        $script:OrigPoshAcmeHome = $env:POSHACME_HOME
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-int-uc3-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null

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

        # Pre-populate the Manual-plugin sidecar so Invoke-OrderCertificate
        # finds saved credentials (Posh-ACME 4.x has no standalone way to
        # persist plugin args — TU-ACME stores them per-plugin via
        # Export-Clixml, and the order flow reads from that sidecar).
        $sidecar = Join-Path $env:ProgramData 'TU-ACME\plugin-args-Manual.xml'
        @{ ManualNonInteractive = $true } | Export-Clixml -Path $sidecar
    }

    AfterAll {
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
        if ($script:PebbleProd)    { Stop-PebbleServer $script:PebbleProd }
        if ($script:PebbleStaging) { Stop-PebbleServer $script:PebbleStaging }
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData   = $script:OrigProgramData
        $env:POSHACME_HOME = $script:OrigPoshAcmeHome
    }

    It 'UC-3.x: issues a real cert against the prod ACME account on Pebble' {
        InModuleScope TU-ACME {
            Mock Invoke-ConsoleClear  {}
            Mock Show-Spinner         { param($Message,$ScriptBlock) & $ScriptBlock }
            Mock Write-EventLogEntry  {}

            # Wizard-prompt sequence for Invoke-OrderCertificate:
            #   domain, sans (empty), plugin name, confirm (y), press-enter.
            $script:_ans = @('order-test.example', '', 'Manual', 'y', '')
            $script:_idx = 0
            Mock Read-Host {
                $v = $script:_ans[$script:_idx]
                $script:_idx = $script:_idx + 1
                return $v
            }

            Invoke-OrderCertificate

            # Assert: the new cert is in the Posh-ACME store under the prod
            # account. Pebble (and other internal CAs — see memory note
            # posh-acme-internal-ca-empty-fields.md) return MainDomain=''
            # so we filter via the AllSANs collection, which is reliably
            # populated from what was passed to -Domain.
            $newCert = @(Get-PACertificate -List | Where-Object { $_.AllSANs -contains 'order-test.example' })
            $newCert.Count             | Should -Be 1
            $newCert[0].Thumbprint     | Should -Not -BeNullOrEmpty
            $newCert[0].AllSANs        | Should -Contain 'order-test.example'
        }
    }

    It 'UC-3.05: aborts and emits no cert when no sidecar plugin args exist' {
        # Drop the sidecar so Get-TUACMEConfig... actually the order flow
        # reads plugin-args-Manual.xml. Remove it and the order must abort
        # *before* New-PACertificate runs.
        $sidecar = Join-Path $env:ProgramData 'TU-ACME\plugin-args-Manual.xml'
        if (Test-Path -LiteralPath $sidecar) { Remove-Item -LiteralPath $sidecar -Force }

        InModuleScope TU-ACME {
            Mock Invoke-ConsoleClear  {}
            Mock Show-Spinner         { param($Message,$ScriptBlock) & $ScriptBlock }
            Mock Write-EventLogEntry  {}
            Mock New-PACertificate    {}   # if anything reaches this, the test fails the assertion below

            $script:_ans2 = @('another.example', '', 'Manual', '')   # last '' = press-enter after the warning
            $script:_idx2 = 0
            Mock Read-Host {
                $v = $script:_ans2[$script:_idx2]
                $script:_idx2 = $script:_idx2 + 1
                return $v
            }

            Invoke-OrderCertificate

            Assert-MockCalled New-PACertificate -Times 0 -Scope It -Exactly
        }
    }
}
