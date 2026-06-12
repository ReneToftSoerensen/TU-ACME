function Save-TUACMEConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Config,

        [string]$Path
    )

    if ([string]::IsNullOrEmpty($Path)) {
        $Path = Get-TUACMEConfigPath
    }

    $directory = Split-Path -Path $Path -Parent
    if (-not (Test-Path -LiteralPath $directory)) {
        $null = New-Item -ItemType Directory -Path $directory -Force
    }

    $Config | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $Path -Encoding UTF8
}
