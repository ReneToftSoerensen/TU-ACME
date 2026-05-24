#Requires -Modules Pester
Describe 'UC-3.01 — Order calls Use-TUACMEProdAccount first' -Tag 'Unit' {
    BeforeAll {
        $ModulePath = "$PSScriptRoot\..\..\..\TU-ACME\TU-ACME.psd1"
        Import-Module $ModulePath -Force
        . "$PSScriptRoot\..\..\Fixtures\FakeObjects.ps1"

        $script:OriginalProgramData = $env:ProgramData
        $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-uc301-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null

        $cfg = [PSCustomObject]@{
            Version = '0.1.0'
            Acme    = [PSCustomObject]@{
                ProdDirectoryUrl    = 'https://prod.example/dir'
                StagingDirectoryUrl = 'https://staging.example/dir'
                ProdAccountId       = 'prod1'
                StagingAccountId    = 'stag1'
                ContactEmail        = 'ops@example.com'
                Initialized         = $true
                InitializedAt       = '2026-05-24T00:00:00Z'
            }
        }
        $cfg | ConvertTo-Json -Depth 5 |
            Set-Content -Path (Join-Path $env:ProgramData 'TU-ACME\config.json') -Encoding UTF8
    }

    AfterAll {
        if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
            Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:ProgramData = $script:OriginalProgramData
        Remove-Module TU-ACME -Force -ErrorAction SilentlyContinue
    }

    It 'calls Use-TUACMEProdAccount before New-PACertificate' {
        InModuleScope TU-ACME {
            Mock Use-TUACMEProdAccount {}
            Mock Set-PAServer  {}
            Mock Set-PAAccount {}
            Mock Get-PAPlugin       { @([PSCustomObject]@{ Name = 'Manual' }) }
            Mock Get-PAPluginArgs   { @{ ApiKey = 'dummy' } }
            Mock New-PACertificate  { [PSCustomObject]@{ Thumbprint = 'ABC123' } }
            Mock Write-EventLogEntry {}
            Mock Show-Spinner       { param($Message, $ScriptBlock) & $ScriptBlock }
            Mock Invoke-ConsoleClear {}

            $script:_ans = @('example.com', '', 'Manual', 'y', '')
            $script:_i = 0
            Mock Read-Host { $v = $script:_ans[$script:_i]; $script:_i++; return $v }

            Invoke-OrderCertificate

            Assert-MockCalled Use-TUACMEProdAccount -Times 1 -Scope It
            Assert-MockCalled New-PACertificate     -Times 1 -Scope It
        }
    }
}
