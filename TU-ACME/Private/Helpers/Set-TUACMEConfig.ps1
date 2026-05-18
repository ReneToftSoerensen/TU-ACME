function Set-TUACMEConfig {
    param(
        [Parameter(Mandatory)] [PSCustomObject] $Config
    )

    $configDir  = Join-Path $env:ProgramData 'TU-ACME'
    $configPath = Join-Path $configDir 'config.json'

    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    $Config | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath -Encoding UTF8
}
