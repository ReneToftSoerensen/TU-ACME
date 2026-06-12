function Get-TUACMEConfigPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # TUACME_DATA_DIR overrides the data directory for tests and non-Windows
    # development; production resolves to %ProgramData%\TU-ACME.
    $dataDir = $env:TUACME_DATA_DIR
    if ([string]::IsNullOrEmpty($dataDir)) {
        $baseDir = $env:ProgramData
        if ([string]::IsNullOrEmpty($baseDir)) {
            $baseDir = [System.IO.Path]::GetTempPath()
        }
        $dataDir = Join-Path $baseDir 'TU-ACME'
    }

    return (Join-Path $dataDir 'config.json')
}
