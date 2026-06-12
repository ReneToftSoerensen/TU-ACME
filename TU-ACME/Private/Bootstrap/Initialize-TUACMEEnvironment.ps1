function Initialize-TUACMEEnvironment {
    [CmdletBinding()]
    param()

    if ((Test-TUACMEIsWindows) -and
        [string]::IsNullOrEmpty($env:POSHACME_HOME) -and
        -not [string]::IsNullOrEmpty($env:ProgramData)) {
        $env:POSHACME_HOME = Join-Path $env:ProgramData 'Posh-ACME'
    }

    if (-not (Import-TUACMEPoshACME)) {
        Write-Warning ('Posh-ACME is not installed. Install it from the PowerShell ' +
            'Gallery before running certificate operations.')
    }

    $configPath = Get-TUACMEConfigPath
    if (Test-Path -LiteralPath $configPath) {
        $null = Get-TUACMEConfig -Path $configPath
        return
    }

    # Import must never prompt or fail (AC-A.1); the wizard runs from
    # Start-TUACME so non-interactive sessions are never blocked.
    Write-Warning 'TU-ACME is not configured. Run Start-TUACME to complete first-run setup.'
}
