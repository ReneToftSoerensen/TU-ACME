function Get-TUACMEConfig {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$Path,

        [bool]$RequireAccountIds = $true
    )

    if ([string]::IsNullOrEmpty($Path)) {
        $Path = Get-TUACMEConfigPath
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        throw ('TU-ACME configuration not found at ''{0}''. Run Start-TUACME to complete first-run setup.' -f $Path)
    }

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    try {
        $config = $raw | ConvertFrom-Json
    }
    catch {
        throw ('TU-ACME configuration at ''{0}'' is not valid JSON: {1}' -f $Path, $_.Exception.Message)
    }

    $null = Test-TUACMEConfig -Config $config -RequireAccountIds $RequireAccountIds -ThrowOnInvalid
    return $config
}
