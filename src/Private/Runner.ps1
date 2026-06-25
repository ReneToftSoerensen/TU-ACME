<#
    Runner.ps1 - Unattended renewal orchestration (ISSUE-02). The headless entry
    script PoshAcme-Renew.ps1 is a thin wrapper that imports the module and calls
    Invoke-TUACMERenewal; the actual algorithm lives here so it shares the
    interactive wizard's install/rebind helpers (Private/Deploy.ps1) and is
    unit-testable with mocks. Logging only - no Read-Host / Write-Host UI.
#>

function Write-TUACMEEventLog {
    <#
        .SYNOPSIS
            Writes one Windows Application event under the TU-ACME source so
            existing monitoring can subscribe. Ensures the source exists first.
            Never throws: an Event Log failure must not abort a renewal run.
        .PARAMETER Message
            Event message body.
        .PARAMETER EntryType
            Information (success) | Warning (partial) | Error (fatal).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Information', 'Warning', 'Error')][string]$EntryType = 'Information',
        [int]$EventId = 1000,
        [string]$Source = $script:EventLogSource
    )
    if (-not (Test-TUACMEOnWindows)) { return }
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($Source)) {
            New-EventLog -LogName 'Application' -Source $Source -ErrorAction Stop
        }
        Write-EventLog -LogName 'Application' -Source $Source -EntryType $EntryType `
            -EventId $EventId -Message $Message -ErrorAction Stop
    } catch {
        # Source creation needs admin; under SYSTEM it succeeds, but degrade gracefully.
        Write-TUACMELog -Level WARN -Message "Could not write Windows Event Log entry: $_"
    }
}

function Resolve-TUACMERenewalTargets {
    <#
        .SYNOPSIS
            Resolves the (server, account) tuples to renew, honoring the stable
            -ServerName / -AccountID seam. Implements the AccountID-only
            convenience fallback: when only -AccountID is given, the server is
            inferred from the single matching tuple.
        .OUTPUTS
            A result object: @{ Targets = <tuple[]>; Status = 'ok'|'none'|'notfound'|'ambiguous'; Message = <string> }.
            Targets are objects from Get-AllPAAccounts (ServerName/ServerArg/AccountID/...).
    #>
    [CmdletBinding()]
    param(
        [string]$ServerName = '',
        [string]$AccountID  = ''
    )

    $all = @(Get-AllPAAccounts)
    if (-not $all -or $all.Count -eq 0) {
        return [pscustomobject]@{ Targets = @(); Status = 'none'; Message = 'No ACME accounts found.' }
    }

    $targets = $all
    if ($ServerName) {
        $targets = @($targets | Where-Object {
            $_.ServerName -ieq $ServerName -or $_.ServerArg -ieq $ServerName -or $_.ServerLoc -ieq $ServerName
        })
    }

    if ($AccountID) {
        $matched = @($targets | Where-Object { $_.AccountID -eq $AccountID })

        # AccountID-only convenience fallback: infer the server from the account.
        if (-not $ServerName) {
            if ($matched.Count -eq 0) {
                return [pscustomobject]@{
                    Targets = @(); Status = 'notfound'
                    Message = "Account '$AccountID' was not found on any known server."
                }
            }
            if ($matched.Count -gt 1) {
                $servers = ($matched | ForEach-Object { $_.ServerName }) -join ', '
                return [pscustomobject]@{
                    Targets = @(); Status = 'ambiguous'
                    Message = ("Account '$AccountID' exists on multiple servers ($servers); " +
                               'disambiguate with -ServerName.')
                }
            }
            $inferred = $matched[0].ServerName
            return [pscustomobject]@{
                Targets = $matched; Status = 'ok'
                Message = "Inferred server '$inferred' from account '$AccountID'."
            }
        }

        $targets = $matched
    }

    if (-not $targets -or $targets.Count -eq 0) {
        return [pscustomobject]@{ Targets = @(); Status = 'none'; Message = 'No matching accounts for the given filters.' }
    }
    return [pscustomobject]@{ Targets = @($targets); Status = 'ok'; Message = '' }
}

function Invoke-TUACMERenewal {
    <#
        .SYNOPSIS
            Headless renewal orchestrator (ISSUE-02). Renews due Posh-ACME orders,
            re-installs the renewed certs into the configured store, and re-points
            the matching IIS HTTPS bindings - reusing the shared Deploy.ps1 helpers
            so unattended and interactive renewals behave identically.
        .OUTPUTS
            [int] process exit code: 0 success (incl. nothing due), 1 partial
            failure (>=1 renewal/rebind/hook failed), 2 fatal/setup error.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '',
        Justification = 'Headless runner; -WhatIf is tracked via $script:WhatIf and forwarded to ShouldProcess-aware helpers downstream.')]
    param(
        [string]$ServerName,
        [string]$AccountID,
        [switch]$Force,
        [switch]$NoCache,
        [string]$CertStore,
        [string]$PostDeployHook,
        [string]$LogPath
    )

    # ----- Setup -----
    if ($PSBoundParameters.ContainsKey('LogPath') -and $LogPath) { $script:LogPath = $LogPath }
    $WhatIf = [bool]$WhatIfPreference
    if ($PSBoundParameters.ContainsKey('WhatIf')) { $WhatIf = [bool]$PSBoundParameters['WhatIf'] }
    $script:WhatIf = $WhatIf
    if ($WhatIf) { $WhatIfPreference = $true }

    $store = if ($PSBoundParameters.ContainsKey('CertStore') -and $CertStore) { $CertStore }
             else { $script:Config.CertStore }
    $hook  = if ($PSBoundParameters.ContainsKey('PostDeployHook')) { $PostDeployHook }
             else { $script:Config.PostDeployHook }

    Write-TUACMELog -Message '====== TU-ACME unattended renewal: start ======'
    if ($WhatIf)  { Write-TUACMELog -Message 'WHAT-IF: no changes will be made.' }
    if ($NoCache) { Write-TUACMELog -Message 'NoCache: bypassing cached state; orders will be refreshed from the server.' }

    # Resolve the shared Posh-ACME home so SYSTEM sees the same store as the admin.
    try {
        $machineHome = $null
        if (Test-TUACMEOnWindows) {
            $machineHome = [Environment]::GetEnvironmentVariable('POSHACME_HOME', 'Machine')
        }
        if ($machineHome) {
            $env:POSHACME_HOME = $machineHome
        } elseif (-not $env:POSHACME_HOME) {
            $env:POSHACME_HOME = $script:SharedACMEHome
            Write-TUACMELog -Level WARN -Message "POSHACME_HOME not set machine-wide; falling back to $($script:SharedACMEHome)."
        }
        Write-TUACMELog -Message "POSHACME_HOME = $($env:POSHACME_HOME)"
    } catch {
        Write-TUACMELog -Level ERROR -Message "Failed to resolve POSHACME_HOME: $_"
        Write-TUACMEEventLog -EntryType Error -Message "TU-ACME renewal fatal: cannot resolve POSHACME_HOME. $_"
        return 2
    }

    # ----- Enumerate target (server, account) tuples -----
    $resolved = Resolve-TUACMERenewalTargets -ServerName $ServerName -AccountID $AccountID
    switch ($resolved.Status) {
        'ok' {
            if ($resolved.Message) { Write-TUACMELog -Message $resolved.Message }
        }
        'none' {
            Write-TUACMELog -Level ERROR -Message $resolved.Message
            Write-TUACMEEventLog -EntryType Error -Message "TU-ACME renewal fatal: $($resolved.Message)"
            return 2
        }
        default {
            # notfound / ambiguous
            Write-TUACMELog -Level ERROR -Message $resolved.Message
            Write-TUACMEEventLog -EntryType Error -Message "TU-ACME renewal fatal: $($resolved.Message)"
            return 2
        }
    }
    $targets = @($resolved.Targets)

    $renewedTotal = 0
    $reboundTotal = 0
    $failedTotal  = 0

    foreach ($acct in $targets) {
        try {
            $srvArg = if ($acct.ServerArg) { $acct.ServerArg } else { $acct.ServerName }
            Write-TUACMELog -Message "Account [$($acct.ServerName)] $($acct.AccountID): activating context."
            Set-PAServer $srvArg -ErrorAction Stop | Out-Null
            Set-PAAccount -ID $acct.AccountID -ErrorAction Stop | Out-Null

            # Snapshot current HTTPS bindings (host header -> thumbprint) for the
            # old-thumbprint rebind fallback when a SAN yields no host-header match.
            $snapshot = @()
            try { $snapshot = @(Get-IISSslBindings) } catch {
                Write-TUACMELog -Level WARN -Message "Could not snapshot IIS bindings: $_"
            }

            # NoCache: refresh order/ARI state from the server before deciding what is due.
            if ($NoCache) {
                try { Get-PAOrder -List -Refresh -ErrorAction Stop | Out-Null } catch {
                    Write-TUACMELog -Level WARN -Message "NoCache refresh failed for [$($acct.ServerName)]: $_"
                }
            }

            if ($WhatIf) {
                $cmd = if ($Force) { 'Submit-Renewal -AllOrders -Force' } else { 'Submit-Renewal -AllOrders' }
                Write-TUACMELog -Message "WHAT-IF: would run '$cmd' for [$($acct.ServerName)] $($acct.AccountID)."
                continue
            }

            # ----- Renew -----
            $renewed = @()
            try {
                if ($Force) {
                    $renewed = @(Submit-Renewal -AllOrders -Force -ErrorAction Stop)
                } else {
                    $renewed = @(Submit-Renewal -AllOrders -ErrorAction Stop)
                }
            } catch {
                $msg = "$_"
                if ($msg -match 'decrypt|padding|cryptograph|Bad Data') {
                    Write-TUACMELog -Level ERROR -Message ("Renewal failed to decrypt secure plugin args under this identity. " +
                        "Run account management in TU-ACME to enable portable encryption " +
                        "(Set-PAAccount -UseAltPluginEncryption) for [$($acct.ServerName)] $($acct.AccountID).")
                } else {
                    Write-TUACMELog -Level ERROR -Message "Submit-Renewal failed for [$($acct.ServerName)] $($acct.AccountID): $msg"
                }
                $failedTotal++
                continue
            }

            if (-not $renewed -or $renewed.Count -eq 0) {
                Write-TUACMELog -Message "No orders due for [$($acct.ServerName)] $($acct.AccountID)."
                continue
            }

            # ----- Per renewed cert: install + rebind + hook -----
            foreach ($cert in $renewed) {
                if (-not $cert -or -not $cert.Thumbprint) { continue }
                try {
                    $newTP = $cert.Thumbprint
                    $sans  = @($cert.AllSANs)
                    $renewedTotal++

                    # Old thumbprint via the pre-renewal binding snapshot (SAN match).
                    $oldTP = ''
                    $match = $snapshot | Where-Object { $_.HostHeader -and ($_.HostHeader -in $sans) } | Select-Object -First 1
                    if ($match) { $oldTP = $match.Thumbprint }

                    Write-TUACMELog -Message "Renewed '$($cert.Subject)' -> $newTP (old: $(if ($oldTP) { $oldTP } else { 'n/a' }))."

                    Install-TUACMECertificate -OrderName $cert.MainDomain -StoreName $store

                    $res = Update-IISCertificateBinding -Thumbprint $newTP -HostHeaders $sans `
                        -OldThumbprint $oldTP -StoreName $store
                    $reboundTotal += $res.Rebound
                    $failedTotal  += $res.Failed
                    Write-TUACMELog -Message "Rebind '$($cert.Subject)': rebound=$($res.Rebound) failed=$($res.Failed)."

                    if ($hook) {
                        if (-not (Invoke-TUACMEPostDeployHook -Certificate $cert -HookPath $hook -StoreName $store)) {
                            $failedTotal++
                        }
                    }
                } catch {
                    Write-TUACMELog -Level ERROR -Message "Deploy failed for renewed cert '$($cert.Subject)': $_"
                    $failedTotal++
                }
            }
        } catch {
            Write-TUACMELog -Level ERROR -Message "Account [$($acct.ServerName)] $($acct.AccountID) failed: $_"
            $failedTotal++
        }
    }

    # ----- Aggregate, Event Log, exit code -----
    $summary = "renewed=$renewedTotal rebound=$reboundTotal failed=$failedTotal"
    Write-TUACMELog -Message "Summary: $summary"
    Write-TUACMELog -Message '====== TU-ACME unattended renewal: end ======'

    if ($failedTotal -gt 0) {
        Write-TUACMEEventLog -EntryType Warning -Message "TU-ACME renewal partial failure. $summary"
        return 1
    }
    Write-TUACMEEventLog -EntryType Information -Message "TU-ACME renewal success. $summary"
    return 0
}
