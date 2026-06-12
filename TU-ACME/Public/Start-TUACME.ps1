function Start-TUACME {
    <#
    .SYNOPSIS
    Entry point for the TU-ACME interactive experience.

    .DESCRIPTION
    Runs the first-run wizard when TU-ACME is not yet configured; otherwise
    shows the current configuration summary. The interactive TUI menu ships
    in Phase 2.
    #>
    [CmdletBinding()]
    param()

    $configPath = Get-TUACMEConfigPath
    if (-not (Test-Path -LiteralPath $configPath)) {
        $null = Invoke-TUACMEFirstRunWizard
        return
    }

    # A failed first run can leave a partial config behind; re-running the
    # wizard is the recovery path rather than leaving the operator stuck.
    $config = $null
    try {
        $config = Get-TUACMEConfig -Path $configPath
    }
    catch {
        Write-Warning ('Existing configuration is incomplete or invalid: {0}' -f $_.Exception.Message)
        Write-Warning 'Restarting first-run setup.'
        $null = Invoke-TUACMEFirstRunWizard
        return
    }

    $version = ''
    $module = Get-Module -Name 'TU-ACME'
    if ($null -ne $module) {
        $version = $module.Version.ToString()
    }

    Write-TUACMEEventLog -EventId 1000 -EntryType Information -Message ('TU-ACME session started (version {0}).' -f $version)

    Write-Host ('TU-ACME {0}' -f $version) -ForegroundColor Cyan
    Write-Host ('Contact email : {0}' -f $config.ContactEmail) -ForegroundColor DarkCyan
    Write-Host ('Production    : {0}' -f $config.ProdDirectoryUrl) -ForegroundColor DarkCyan
    Write-Host ('Staging       : {0}' -f $config.StagingDirectoryUrl) -ForegroundColor DarkCyan
    Write-Host 'The interactive TUI menu arrives in Phase 2.' -ForegroundColor Cyan
}
