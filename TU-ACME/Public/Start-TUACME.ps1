function Start-TUACME {
    <#
    .SYNOPSIS
        Starts the TU-ACME Terminal UI for managing Posh-ACME certificates
        against an internal corporate ACME CA.
    #>
    [CmdletBinding()]
    param()

    if (-not (Get-Module -ListAvailable -Name 'Posh-ACME')) {
        Write-Host ''
        Write-Host '  [ERROR] The Posh-ACME module is not installed.' -ForegroundColor Red
        Write-Host '  Install with: Install-Module -Name Posh-ACME -Scope AllUsers' -ForegroundColor Yellow
        Write-Host ''
        return
    }

    $script:TUACMEIsAdmin = Get-AdminStatus

    $configDir = Join-Path $env:ProgramData 'TU-ACME'
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    if ($script:TUACMEIsAdmin) {
        Write-EventLogEntry -EventId 1000 -Message 'TU-ACME started.' -EntryType Information
    }

    # First-run gate — full wizard arrives in Step 4 (UC-1.x).
    $cfg = Get-TUACMEConfig
    if (-not $cfg.Acme.Initialized) {
        Write-Host ''
        Write-Host '  TU-ACME has not been initialized. Run the first-run wizard.' -ForegroundColor Yellow
        Write-Host '  (Wizard implementation lands in Step 4.)' -ForegroundColor DarkGray
        Write-Host ''
        return
    }

    Invoke-ConsoleClear
    Show-StatusBar
    Write-Host '  TU-ACME v0.1.0 - menu skeleton (Step 3). Full menu arrives in later steps.' -ForegroundColor Cyan
}
