#Requires -Modules Pester
Describe 'Initialize-TUACMEEnvironment against Pebble (live)' -Tag 'Integration' {

    BeforeAll {
        $script:RepoRoot   = Resolve-Path "$PSScriptRoot\..\.."
        $script:ModulePath = Join-Path $script:RepoRoot 'TU-ACME\TU-ACME.psd1'

        Import-Module (Join-Path $PSScriptRoot 'Pebble.psm1') -Force
        $script:PebbleProd    = Start-PebbleServer -Role Prod
        $script:PebbleStaging = Start-PebbleServer -Role Staging

        # Sandbox both the TU-ACME config and the Posh-ACME store so the
        # test doesn't pollute or pick up real account state.
        $script:OrigProgramData  = $env:ProgramData
        $script:OrigPoshAcmeHome = $env:POSHACME_HOME
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-int-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null

        Import-Module $script:ModulePath -Force
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

    It 'creates a prod and a staging ACME account on Pebble and persists IDs' {
        $prodUrl    = $script:PebbleProd.DirectoryUrl
        $stagingUrl = $script:PebbleStaging.DirectoryUrl

        InModuleScope TU-ACME -Parameters @{ ProdUrl = $prodUrl; StagingUrl = $stagingUrl } {
            param($ProdUrl, $StagingUrl)

            Mock Invoke-ConsoleClear  {}
            Mock Show-Spinner         { param($Message,$ScriptBlock) & $ScriptBlock }
            Mock Write-EventLogEntry  {}

            $answers = @(
                $ProdUrl,
                $StagingUrl,
                'ops@example.com',
                'y'
            )
            $script:_ans = $answers
            $script:_i   = 0
            Mock Read-Host {
                $v = $script:_ans[$script:_i]
                $script:_i = $script:_i + 1
                return $v
            }

            Initialize-TUACMEEnvironment

            $cfg = Get-TUACMEConfig
            $cfg.Acme.Initialized         | Should -BeTrue
            $cfg.Acme.ProdAccountId       | Should -Not -BeNullOrEmpty
            $cfg.Acme.StagingAccountId    | Should -Not -BeNullOrEmpty
            $cfg.Acme.ProdAccountId       | Should -Not -Be $cfg.Acme.StagingAccountId
            $cfg.Acme.ProdDirectoryUrl    | Should -Be $ProdUrl
            $cfg.Acme.StagingDirectoryUrl | Should -Be $StagingUrl
            $cfg.Acme.ContactEmail        | Should -Be 'ops@example.com'
        }
    }

    It 'Use-TUACMEProdAccount switches Posh-ACME back to the persisted prod account' {
        InModuleScope TU-ACME {
            { Use-TUACMEProdAccount } | Should -Not -Throw
            $active = Get-PAAccount
            $active.id | Should -Not -BeNullOrEmpty
        }
    }

    It 'Use-TUACMEStagingAccount switches Posh-ACME to the staging account' {
        InModuleScope TU-ACME {
            { Use-TUACMEStagingAccount } | Should -Not -Throw
            $active = Get-PAAccount
            $active.id | Should -Not -BeNullOrEmpty
        }
    }
}
