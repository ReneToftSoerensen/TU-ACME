<#
    Config.ps1 - Load/save %ProgramData%\TU-ACME\config.json and the shared log.
#>

function Save-TUACMEConfig {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $dir = Split-Path $script:ConfigFile -Parent
    if (-not (Test-Path $dir)) {
        if ($PSCmdlet.ShouldProcess($dir, 'Create config directory')) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    if ($PSCmdlet.ShouldProcess($script:ConfigFile, 'Write configuration')) {
        $script:Config | ConvertTo-Json -Depth 6 | Set-Content -Path $script:ConfigFile -Encoding UTF8
    }
}

function Import-TUACMEConfig {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if (Test-Path $script:ConfigFile) {
        try {
            $json = Get-Content $script:ConfigFile -Raw | ConvertFrom-Json -AsHashtable
            foreach ($key in $json.Keys) { $script:Config[$key] = $json[$key] }
        } catch {
            Write-Warn "Could not load config from $($script:ConfigFile): $_"
        }
    } else {
        Save-TUACMEConfig
    }
}

function Write-TUACMELog {
    <#
        .SYNOPSIS
            Appends one ISO-8601 timestamped line to the shared renewal log.
            Used by both the interactive TUI and the unattended runner (ISSUE-02).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO',
        [string]$Path = $script:LogPath
    )
    try {
        $dir = Split-Path $Path -Parent
        if ($dir -and -not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        $stamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
        Add-Content -Path $Path -Value ("{0} [{1}] {2}" -f $stamp, $Level, $Message) -Encoding UTF8
    } catch {
        # Logging must never throw and abort the caller.
        Write-Info "Could not write to log '$Path': $_"
    }
}
