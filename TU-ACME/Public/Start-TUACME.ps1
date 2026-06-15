function Start-TUACME {
    <#
    .SYNOPSIS
    Entry point for the TU-ACME interactive experience.

    .DESCRIPTION
    Runs the first-run wizard when TU-ACME is not yet configured; otherwise
    starts the interactive TUI main menu for certificate operations.
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
        # DarkCyan, not Write-Warning: the TUI palette is locked (AC-C.4).
        Write-Host ('Existing configuration is incomplete or invalid: {0}' -f $_.Exception.Message) -ForegroundColor DarkCyan
        Write-Host 'Restarting first-run setup.' -ForegroundColor DarkCyan
        $null = Invoke-TUACMEFirstRunWizard
        return
    }

    $version = ''
    $module = Get-Module -Name 'TU-ACME'
    if ($null -ne $module) {
        $version = $module.Version.ToString()
    }

    Write-TUACMEEventLog -EventId 1000 -EntryType Information -Message ('TU-ACME session started (version {0}).' -f $version)

    $menuItems = @(
        'Certificate dashboard'
        'Order certificate'
        'Dry-run order (staging)'
        'Renew certificate'
        'Install scheduled renewal task'
        'Configure SMTP notifications'
        'Configure DNS plugin'
        'Exit'
    )

    # The contact email is operator-supplied and unbounded; clamp the
    # composed title to the 79-char cap Show-TUACMEMenu enforces (AC-C.3).
    $menuTitle = 'TU-ACME {0} - {1}' -f $version, $config.ContactEmail
    if ($menuTitle.Length -gt 79) {
        $menuTitle = $menuTitle.Substring(0, 79)
    }

    $disabledIndices = @()
    if (-not (Test-TUACMEIsAdministrator)) {
        $disabledIndices += [array]::IndexOf($menuItems, 'Install scheduled renewal task')
    }

    while ($true) {
        $selection = Show-TUACMEMenu -Title $menuTitle -Items $menuItems -DisabledIndices $disabledIndices
        if ($selection -lt 0 -or $menuItems[$selection] -eq 'Exit') {
            return
        }

        try {
            switch ($menuItems[$selection]) {
                'Certificate dashboard' {
                    Show-TUACMEDashboard
                }
                'Order certificate' {
                    $domain = ([string](Read-Host 'Domain to order')).Trim()
                    if (-not [string]::IsNullOrEmpty($domain)) {
                        $result = Invoke-TUACMEOrderCertificate -Domain $domain
                        Write-Host ('Ordered {0} (thumbprint {1}, expires {2:yyyy-MM-dd}).' -f $result.Domain, $result.Thumbprint, $result.NotAfter) -ForegroundColor Cyan
                    }
                }
                'Dry-run order (staging)' {
                    $domain = ([string](Read-Host 'Domain for the staging dry-run')).Trim()
                    if (-not [string]::IsNullOrEmpty($domain)) {
                        $result = Invoke-TUACMEOrderCertificate -Domain $domain -DryRun
                        Write-Host ('Dry-run issued {0} against staging (thumbprint {1}). Production is unchanged.' -f $result.Domain, $result.Thumbprint) -ForegroundColor Cyan
                    }
                }
                'Renew certificate' {
                    $domains = @(Get-TUACMECertificate | ForEach-Object { [string]$_.MainDomain })
                    if ($domains.Count -eq 0) {
                        Write-Host 'No certificates to renew yet. Order one first.' -ForegroundColor Cyan
                    }
                    else {
                        $certSelection = Show-TUACMEMenu -Title 'Select a certificate to renew' -Items $domains
                        if ($certSelection -ge 0) {
                            $result = Invoke-TUACMERenewCertificate -Domain $domains[$certSelection]
                            Write-Host ('Renewed {0} (new thumbprint {1}).' -f $result.Domain, $result.NewThumbprint) -ForegroundColor Cyan
                        }
                    }
                }
                'Install scheduled renewal task' {
                    $confirmation = ([string](Read-Host 'Create the TU-ACME-Renewal scheduled task? (y/N)')).Trim()
                    if ($confirmation -eq 'y') {
                        $null = Install-TUACMEScheduledTask
                    }
                }
                'Configure SMTP notifications' {
                    $server = ([string](Read-Host 'SMTP server')).Trim()
                    $portText = ([string](Read-Host 'SMTP port (default 25)')).Trim()
                    $port = 25
                    if (-not [string]::IsNullOrEmpty($portText)) {
                        $port = [int]$portText
                    }
                    $username = ([string](Read-Host 'SMTP username (blank for none)')).Trim()
                    $password = Read-Host 'SMTP password' -AsSecureString
                    Set-TUACMESMTPConfig -Server $server -Port $port -Username $username -Password $password
                    Write-Host 'SMTP settings saved; the password is stored encrypted.' -ForegroundColor Cyan
                }
                'Configure DNS plugin' {
                    $pluginName = ([string](Read-Host 'Posh-ACME DNS plugin name')).Trim()
                    $pluginArgs = @{}
                    while ($true) {
                        $argumentName = ([string](Read-Host 'Plugin argument name (blank to finish)')).Trim()
                        if ([string]::IsNullOrEmpty($argumentName)) {
                            break
                        }
                        $pluginArgs[$argumentName] = Read-Host ('Value for {0}' -f $argumentName) -AsSecureString
                    }
                    if (-not [string]::IsNullOrEmpty($pluginName) -and $pluginArgs.Count -gt 0) {
                        Set-TUACMEDNSConfig -PluginName $pluginName -PluginArgs $pluginArgs
                        Write-Host 'DNS plugin settings saved; all argument values are stored encrypted.' -ForegroundColor Cyan
                    }
                }
            }
        }
        catch {
            # Cyan, not Red: the palette is locked to Cyan/DarkCyan (AC-C.4).
            Write-Host ('Operation failed: {0}' -f $_.Exception.Message) -ForegroundColor Cyan
        }

        if ($menuItems[$selection] -ne 'Certificate dashboard') {
            Write-Host 'Press any key to return to the menu.' -ForegroundColor DarkCyan
            $null = Read-TUACMEKey
        }
    }
}
