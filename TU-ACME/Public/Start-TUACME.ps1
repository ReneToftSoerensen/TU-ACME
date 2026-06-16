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
        'Renewal status'
        'Force-renew certificate (new key)'
        'Revoke certificate'
        'Rebind IIS site'
        'Add HTTPS to an IIS site'
        'Clean up unbound certificates'
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
        # IIS rebind and cleanup write to the machine cert stores and IIS
        # configuration, so they need elevation just like the task install.
        $disabledIndices += [array]::IndexOf($menuItems, 'Install scheduled renewal task')
        $disabledIndices += [array]::IndexOf($menuItems, 'Rebind IIS site')
        $disabledIndices += [array]::IndexOf($menuItems, 'Add HTTPS to an IIS site')
        $disabledIndices += [array]::IndexOf($menuItems, 'Clean up unbound certificates')
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
                    $domains = Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)'
                    if (@($domains).Count -gt 0) {
                        $result = Invoke-TUACMEOrderCertificate -Domain $domains
                        Write-Host ('Ordered {0} (thumbprint {1}, expires {2:yyyy-MM-dd}).' -f $result.Domain, $result.Thumbprint, $result.NotAfter) -ForegroundColor Cyan
                        if (@($domains).Count -gt 1) {
                            Write-Host ('Included SAN: {0}.' -f ((@($domains)[1..(@($domains).Count - 1)]) -join ', ')) -ForegroundColor Cyan
                        }
                    }
                }
                'Dry-run order (staging)' {
                    $domains = Get-TUACMEOrderDomain -Prompt 'FQDN for the staging dry-run (CN)'
                    if (@($domains).Count -gt 0) {
                        $result = Invoke-TUACMEOrderCertificate -Domain $domains -DryRun
                        Write-Host ('Dry-run issued {0} against staging (thumbprint {1}). Production is unchanged.' -f $result.Domain, $result.Thumbprint) -ForegroundColor Cyan
                        if (@($domains).Count -gt 1) {
                            Write-Host ('Included SAN: {0}.' -f ((@($domains)[1..(@($domains).Count - 1)]) -join ', ')) -ForegroundColor Cyan
                        }
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
                'Renewal status' {
                    Show-TUACMERenewalStatus
                }
                'Force-renew certificate (new key)' {
                    $domains = @(Get-TUACMECertificate | ForEach-Object { [string]$_.MainDomain })
                    if ($domains.Count -eq 0) {
                        Write-Host 'No certificates to force-renew yet. Order one first.' -ForegroundColor Cyan
                    }
                    else {
                        $certSelection = Show-TUACMEMenu -Title 'Select a certificate to force-renew (new key)' -Items $domains
                        if ($certSelection -ge 0) {
                            $confirmation = ([string](Read-Host ('Force-renew {0} with a brand new key? (y/N)' -f $domains[$certSelection]))).Trim()
                            if ($confirmation -eq 'y') {
                                $result = Invoke-TUACMERenewCertificate -Domain $domains[$certSelection] -NewKey
                                Write-Host ('Force-renewed {0} with a new key (new thumbprint {1}).' -f $result.Domain, $result.NewThumbprint) -ForegroundColor Cyan
                            }
                        }
                    }
                }
                'Revoke certificate' {
                    $domains = @(Get-TUACMECertificate | ForEach-Object { [string]$_.MainDomain })
                    if ($domains.Count -eq 0) {
                        Write-Host 'No certificates to revoke.' -ForegroundColor Cyan
                    }
                    else {
                        $certSelection = Show-TUACMEMenu -Title 'Select a certificate to revoke' -Items $domains
                        if ($certSelection -ge 0) {
                            $confirmation = ([string](Read-Host ('Revoke {0}? This cannot be undone. (y/N)' -f $domains[$certSelection]))).Trim()
                            if ($confirmation -eq 'y') {
                                $result = Invoke-TUACMERevokeCertificate -Domain $domains[$certSelection]
                                Write-Host ('Revoked {0} (thumbprint {1}).' -f $result.Domain, $result.Thumbprint) -ForegroundColor Cyan
                                if (@($result.AffectedBindings).Count -gt 0) {
                                    Write-Host ('{0} IIS binding(s) still reference the revoked cert; rebind them from "Rebind IIS site".' -f @($result.AffectedBindings).Count) -ForegroundColor DarkCyan
                                }
                            }
                        }
                    }
                }
                'Rebind IIS site' {
                    $bindings = @(Get-TUACMEIISBinding | Where-Object { $_.Protocol -eq 'https' })
                    if ($bindings.Count -eq 0) {
                        if (Test-TUACMEIISAvailable) {
                            Write-Host 'No HTTPS bindings found to rebind.' -ForegroundColor Cyan
                        }
                        else {
                            # Distinguish a missing IIS provider from zero bindings
                            # so the operator is not misled (issue #16). DarkCyan
                            # is the advisory tone (AC-C.4).
                            Write-Host 'IIS management is unavailable in this session. Install the IIS Management Scripts and Tools feature, or run TU-ACME under Windows PowerShell 5.1.' -ForegroundColor DarkCyan
                        }
                    }
                    else {
                        $bindingLabels = @($bindings | ForEach-Object { ('{0} - {1}' -f $_.SiteName, $_.BindingInformation) })
                        $bindingSelection = Show-TUACMEMenu -Title 'Select an HTTPS binding to rebind' -Items $bindingLabels
                        if ($bindingSelection -ge 0) {
                            $certificates = @(Get-TUACMECertificate)
                            if ($certificates.Count -eq 0) {
                                Write-Host 'No certificates in the store to bind.' -ForegroundColor Cyan
                            }
                            else {
                                $certLabels = @($certificates | ForEach-Object { ('{0} ({1})' -f [string]$_.MainDomain, [string]$_.Thumbprint) })
                                $certPick = Show-TUACMEMenu -Title 'Select the certificate to bind' -Items $certLabels
                                if ($certPick -ge 0) {
                                    $chosenBinding = $bindings[$bindingSelection]
                                    $chosenCert = $certificates[$certPick]
                                    $rebind = Update-TUACMEIISBinding -SiteName $chosenBinding.SiteName -BindingInformation $chosenBinding.BindingInformation -NewThumbprint ([string]$chosenCert.Thumbprint) -Certificate $chosenCert
                                    Write-Host ('Rebind complete: {0} updated, {1} failed.' -f @($rebind.Updated).Count, @($rebind.Failed).Count) -ForegroundColor Cyan
                                }
                            }
                        }
                    }
                }
                'Add HTTPS to an IIS site' {
                    $httpBindings = @(Get-TUACMEIISBinding | Where-Object { $_.Protocol -eq 'http' })
                    if ($httpBindings.Count -eq 0) {
                        # An empty list is most often issue #16 on PowerShell 7
                        # (WebAdministration not loaded), so point operators at
                        # the remedy rather than implying no HTTP sites exist.
                        Write-Host 'No HTTP bindings found. If IIS is installed, WebAdministration may be unavailable; install IIS Management Scripts and Tools, or run under Windows PowerShell 5.1.' -ForegroundColor Cyan
                    }
                    else {
                        $httpLabels = @($httpBindings | ForEach-Object { ('{0} - {1}' -f $_.SiteName, $_.BindingInformation) })
                        $siteSelection = Show-TUACMEMenu -Title 'Select an HTTP site to add HTTPS to' -Items $httpLabels
                        if ($siteSelection -ge 0) {
                            $chosenBinding = $httpBindings[$siteSelection]

                            $portText = ([string](Read-Host 'HTTPS port (default 443)')).Trim()
                            $port = 443
                            if (-not [string]::IsNullOrEmpty($portText)) {
                                $port = [int]$portText
                            }

                            # Pre-fill the CN from the binding's host header when
                            # present so the common case is a single Enter.
                            $cnDefault = [string]$chosenBinding.HostHeader
                            $cnPrompt = 'Certificate CN (primary domain)'
                            if (-not [string]::IsNullOrEmpty($cnDefault)) {
                                $cnPrompt = 'Certificate CN (Enter for "{0}")' -f $cnDefault
                            }
                            $cn = ([string](Read-Host $cnPrompt)).Trim()
                            if ([string]::IsNullOrEmpty($cn)) {
                                $cn = $cnDefault
                            }

                            if ([string]::IsNullOrEmpty($cn)) {
                                Write-Host 'No CN provided; nothing to order.' -ForegroundColor Cyan
                            }
                            else {
                                $sanText = ([string](Read-Host 'Additional SANs (comma/space separated, blank for none)')).Trim()
                                $san = @($sanText -split '[,\s]+' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrEmpty($_) })

                                $dryRunAnswer = ([string](Read-Host 'Dry-run against staging? Makes no IIS changes. (y/N)')).Trim()
                                $dryRun = ($dryRunAnswer -eq 'y')

                                $httpsParams = @{
                                    SiteName   = $chosenBinding.SiteName
                                    Domain     = $cn
                                    San        = $san
                                    Port       = $port
                                    HostHeader = $cn
                                }
                                if ($dryRun) {
                                    $httpsParams['DryRun'] = $true
                                }
                                $result = New-TUACMEIISHttpsBinding @httpsParams
                                if ($dryRun) {
                                    Write-Host ('Dry-run issued {0} against staging (thumbprint {1}). Production and IIS are unchanged.' -f $result.Domain, $result.Thumbprint) -ForegroundColor Cyan
                                }
                                elseif ($result.BindingCreated -or $result.BindingUpdated) {
                                    Write-Host ('HTTPS provisioned for {0} on site ''{1}'' (port {2}, thumbprint {3}).' -f $result.Domain, $result.SiteName, $result.Port, $result.Thumbprint) -ForegroundColor Cyan
                                }
                                else {
                                    Write-Host ('Certificate ordered for {0} (thumbprint {1}); no HTTPS binding was created.' -f $result.Domain, $result.Thumbprint) -ForegroundColor Cyan
                                }
                            }
                        }
                    }
                }
                'Clean up unbound certificates' {
                    $unbound = @(Get-TUACMEUnboundWebHostingCertificate)
                    if ($unbound.Count -eq 0) {
                        if (Test-TUACMEIISAvailable) {
                            Write-Host 'No unbound certificates in the WebHosting store.' -ForegroundColor Cyan
                        }
                        else {
                            # Distinguish a missing IIS provider from zero certs
                            # so the operator is not misled (issue #16). DarkCyan
                            # is the advisory tone (AC-C.4).
                            Write-Host 'IIS management is unavailable in this session. Install the IIS Management Scripts and Tools feature, or run TU-ACME under Windows PowerShell 5.1.' -ForegroundColor DarkCyan
                        }
                    }
                    else {
                        $labels = @($unbound | ForEach-Object { ('{0} (expires {1:yyyy-MM-dd})' -f $_.Thumbprint, $_.NotAfter) })
                        $pick = Show-TUACMEMenu -Title 'Select an unbound certificate to delete' -Items $labels
                        if ($pick -ge 0) {
                            $confirmation = ([string](Read-Host ('Delete certificate {0} from WebHosting? (y/N)' -f $unbound[$pick].Thumbprint))).Trim()
                            if ($confirmation -eq 'y') {
                                $deleted = Remove-TUACMEWebHostingCertificate -Thumbprint ([string]$unbound[$pick].Thumbprint)
                                if ($deleted) {
                                    Write-Host ('Deleted {0}.' -f $unbound[$pick].Thumbprint) -ForegroundColor Cyan
                                }
                                else {
                                    Write-Host ('Could not delete {0}; see the event log.' -f $unbound[$pick].Thumbprint) -ForegroundColor Cyan
                                }
                            }
                        }
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
                    if ([string]::IsNullOrEmpty($username)) {
                        # Unauthenticated relay: no credential to prompt for or
                        # store (issue #15).
                        Set-TUACMESMTPConfig -Server $server -Port $port -Username $username
                        Write-Host 'SMTP settings saved (unauthenticated relay).' -ForegroundColor Cyan
                    }
                    else {
                        $password = Read-Host 'SMTP password' -AsSecureString
                        Set-TUACMESMTPConfig -Server $server -Port $port -Username $username -Password $password
                        if ($null -ne $password -and $password.Length -gt 0) {
                            Write-Host 'SMTP settings saved; the password is stored encrypted.' -ForegroundColor Cyan
                        }
                        else {
                            # A blank password is stored as no credential, so do
                            # not claim it was encrypted (issue #15 follow-up).
                            Write-Host 'SMTP settings saved; no password entered, so none is stored.' -ForegroundColor Cyan
                        }
                    }
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

        if (@('Certificate dashboard', 'Renewal status') -notcontains $menuItems[$selection]) {
            Write-Host 'Press any key to return to the menu.' -ForegroundColor DarkCyan
            $null = Read-TUACMEKey
        }
    }
}
