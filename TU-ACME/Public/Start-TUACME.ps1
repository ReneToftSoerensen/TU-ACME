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

    $config = Get-TUACMEConfig -Path $configPath

    $version = ''
    $module = Get-Module -Name 'TU-ACME'
    if ($null -ne $module) {
        $version = $module.Version.ToString()
    }

    Write-Host ('TU-ACME {0}' -f $version) -ForegroundColor Cyan
    Write-Host ('Contact email : {0}' -f $config.ContactEmail) -ForegroundColor DarkCyan
    Write-Host ('Production    : {0}' -f $config.ProdDirectoryUrl) -ForegroundColor DarkCyan
    Write-Host ('Staging       : {0}' -f $config.StagingDirectoryUrl) -ForegroundColor DarkCyan
    Write-Host 'The interactive TUI menu arrives in Phase 2.' -ForegroundColor Cyan
}
