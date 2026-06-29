<#
.SYNOPSIS
    Headless certificate renewal runner for TU-ACME.

.DESCRIPTION
    Renews due Posh-ACME orders, imports the new certificates into the
    configured cert store, and re-points the affected IIS HTTPS bindings.
    Designed to run under SYSTEM as a Windows Scheduled Task registered by the
    TU-ACME T menu.

    Reuses Install-TUACMECertificate and Update-IISCertificateBinding from the
    TU-ACME module so interactive and unattended rebinds behave identically.

    Exit codes:
      0 = success (including "nothing was due" no-op).
      1 = one or more renewals or rebinds failed (partial); see log.
      2 = fatal setup error (module unavailable, POSHACME_HOME missing, etc.).

.PARAMETER ServerName
    Posh-ACME server alias or directory URL to restrict processing to.
    Omit to process all configured servers.

.PARAMETER AccountID
    Posh-ACME account ID to restrict processing to.
    Omit to process all accounts on the selected server(s).

.PARAMETER Force
    Pass -Force to Submit-Renewal to renew regardless of RenewAfter (bypass ARI).

.PARAMETER CertStore
    LocalMachine cert store name to import renewed certs into (default: WebHosting).
    Overrides the value in config.json.

.PARAMETER PostDeployHook
    Path to an optional user-supplied .ps1 for non-IIS deployment.
    Overrides the value in config.json. Empty string disables the hook.

.PARAMETER LogPath
    Log file path. Default: %ProgramData%\TU-ACME\renewal.log.

.PARAMETER WhatIf
    Log intended actions; make no changes.

.EXAMPLE
    pwsh -NoProfile -ExecutionPolicy Bypass -File .\PoshAcme-Renew.ps1
    pwsh -NoProfile -ExecutionPolicy Bypass -File .\PoshAcme-Renew.ps1 -ServerName LE_PROD -AccountID abc123
    pwsh -NoProfile -ExecutionPolicy Bypass -File .\PoshAcme-Renew.ps1 -Force
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator
#Requires -Modules Posh-ACME, IISAdministration

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ServerName    = '',
    [string]$AccountID     = '',
    [switch]$Force,
    [string]$CertStore     = '',
    [string]$PostDeployHook = '',
    [string]$LogPath       = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -----------------------------------------------------------------------
# 1. Resolve POSHACME_HOME from machine environment (set by TUI bootstrap).
#    Fall back to the fixed default and log a warning.
# -----------------------------------------------------------------------
$poshAcmeHome = [Environment]::GetEnvironmentVariable('POSHACME_HOME', 'Machine')
$poshAcmeHomeFallback = $false
if (-not $poshAcmeHome) {
    $poshAcmeHome = Join-Path $env:ProgramData 'TU-ACME\ACME'
    $poshAcmeHomeFallback = $true
}
if (-not (Test-Path $poshAcmeHome)) {
    try { New-Item -ItemType Directory -Path $poshAcmeHome -Force | Out-Null } catch { }
}
$env:POSHACME_HOME = $poshAcmeHome

# -----------------------------------------------------------------------
# 2. Resolve log path early so we can write immediately after this point.
# -----------------------------------------------------------------------
$resolvedLogPath = if ($LogPath) { $LogPath } else {
    Join-Path $env:ProgramData 'TU-ACME\renewal.log'
}

function Write-RunLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    $stamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    $line  = "$stamp [$Level] $Message"
    try {
        $dir = Split-Path $resolvedLogPath -Parent
        if ($dir -and -not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        Add-Content -Path $resolvedLogPath -Value $line -Encoding UTF8
    } catch {
        # Logging must not abort processing.
    }
}

# -----------------------------------------------------------------------
# 3. Import the TU-ACME module.  Look for it next to this script (./src/)
#    first, then as an installed module by name.
# -----------------------------------------------------------------------
$modulePath = $null
foreach ($candidate in @(
    (Join-Path $PSScriptRoot 'src\TU-ACME.psd1'),
    (Join-Path $PSScriptRoot 'TU-ACME.psd1')
)) {
    if (Test-Path $candidate) { $modulePath = $candidate; break }
}

try {
    if ($modulePath) {
        Import-Module $modulePath -Force -ErrorAction Stop
    } elseif (Get-Module -ListAvailable -Name 'TU-ACME' -ErrorAction SilentlyContinue) {
        Import-Module 'TU-ACME' -Force -ErrorAction Stop
    } else {
        throw 'TU-ACME module not found. Ensure the module is deployed next to this script or installed system-wide.'
    }
} catch {
    Write-RunLog "Fatal: could not import TU-ACME module: $_" -Level ERROR
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists('TU-ACME')) {
            New-EventLog -LogName Application -Source 'TU-ACME' -ErrorAction SilentlyContinue
        }
        Write-EventLog -LogName Application -Source 'TU-ACME' -EntryType Error -EventId 2000 `
            -Message "TU-ACME renewal runner fatal: could not import module. $_" -ErrorAction SilentlyContinue
    } catch { }
    exit 2
}

# -----------------------------------------------------------------------
# 4. Ensure Windows Event Log source exists.
# -----------------------------------------------------------------------
try {
    if (-not [System.Diagnostics.EventLog]::SourceExists('TU-ACME')) {
        New-EventLog -LogName Application -Source 'TU-ACME' -ErrorAction SilentlyContinue
    }
} catch { }

# -----------------------------------------------------------------------
# 5. Read defaults from config.json; explicit params override.
# -----------------------------------------------------------------------
$config = @{ CertStore = 'WebHosting'; PostDeployHook = '' }
$configFile = Join-Path $env:ProgramData 'TU-ACME\config.json'
if (Test-Path $configFile) {
    try {
        $json = Get-Content $configFile -Raw | ConvertFrom-Json -AsHashtable
        if ($json.ContainsKey('CertStore')      -and $json.CertStore)      { $config.CertStore = $json.CertStore }
        if ($json.ContainsKey('PostDeployHook') -and $json.PostDeployHook) { $config.PostDeployHook = $json.PostDeployHook }
    } catch {
        Write-RunLog "Could not read config from '$configFile': $_" -Level WARN
    }
}

$resolvedStore = if ($CertStore)       { $CertStore }       else { $config.CertStore }
$resolvedHook  = if ($PSBoundParameters.ContainsKey('PostDeployHook')) { $PostDeployHook } else { $config.PostDeployHook }

# -----------------------------------------------------------------------
# 6. Main renewal loop.
# -----------------------------------------------------------------------
$totalRenewed = 0
$totalRebound = 0
$totalFailed  = 0
$exitCode     = 0

Write-RunLog '====== TU-ACME Renewal Run Start ======'
if ($poshAcmeHomeFallback) {
    Write-RunLog "POSHACME_HOME not set in machine environment; using fallback '$poshAcmeHome'" -Level WARN
}
Write-RunLog "POSHACME_HOME=$poshAcmeHome  CertStore=$resolvedStore  Force=$Force  WhatIf=$($WhatIfPreference)"

try {
    Import-Module Posh-ACME -Force -ErrorAction Stop

    # Enumerate all (server, account) tuples known to Posh-ACME.
    $allAccounts = @(Get-AllPAAccounts)
    if (-not $allAccounts) {
        Write-RunLog 'No Posh-ACME accounts found. Nothing to renew.' -Level WARN
        Write-RunLog '====== Summary: renewed=0 rebound=0 failed=0 ======'
        Write-RunLog '====== TU-ACME Renewal Run End (exit 0) ======'
        exit 0
    }

    # Restrict to -ServerName / -AccountID when supplied.
    $targets = $allAccounts
    if ($ServerName) {
        $targets = @($targets | Where-Object {
            $_.ServerName -ieq $ServerName -or $_.ServerArg -ieq $ServerName
        })
    }
    if ($AccountID) {
        $targets = @($targets | Where-Object { $_.AccountID -ieq $AccountID })
    }
    if (-not $targets) {
        Write-RunLog "No accounts match ServerName='$ServerName' AccountID='$AccountID'. Nothing to do." -Level WARN
        Write-RunLog '====== Summary: renewed=0 rebound=0 failed=0 ======'
        Write-RunLog '====== TU-ACME Renewal Run End (exit 0) ======'
        exit 0
    }

    foreach ($acct in $targets) {
        try {
            Write-RunLog "Processing account: [$($acct.ServerName)] $($acct.AccountID)"

            # Warn when secure plugin args cannot be decrypted under SYSTEM.
            if ($acct.NeedsAltEncryption) {
                Write-RunLog ("Account '$($acct.AccountID)' on '$($acct.ServerName)' has secure plugin args " +
                    'but portable (AES) encryption is OFF. Renewal under SYSTEM may fail to decrypt plugin ' +
                    "credentials. Use option 'a' in the TU-ACME S menu to enable portable encryption.") -Level WARN
            }

            # Activate server + account.
            Set-PAServer $acct.ServerArg -ErrorAction Stop | Out-Null
            Set-PAAccount -ID $acct.AccountID -ErrorAction Stop | Out-Null

            # Snapshot pre-renewal HostHeader -> Thumbprint map.
            # Taken BEFORE Submit-Renewal so we always have the pre-renewal thumbprint
            # for the old-thumbprint fallback rebind, even on retry runs where the
            # binding may already carry the new thumbprint.
            $hostThumbSnapshot = @{}
            try {
                foreach ($b in @(Get-IISSslBindings)) {
                    if ($b.HostHeader -and $b.Thumbprint) {
                        $hostThumbSnapshot[$b.HostHeader.ToLower()] = $b.Thumbprint
                    }
                }
                Write-RunLog "IIS snapshot: $($hostThumbSnapshot.Count) HTTPS binding(s) with host headers"
            } catch {
                Write-RunLog "Could not snapshot IIS bindings: $_" -Level WARN
            }

            # ----------------------------------------------------------
            # Renew due orders (or all orders when -Force).
            # ----------------------------------------------------------
            $renewCmd = if ($Force) { 'Submit-Renewal -AllOrders -Force' } else { 'Submit-Renewal -AllOrders' }
            if (-not $PSCmdlet.ShouldProcess("[$($acct.ServerName)] $($acct.AccountID)", $renewCmd)) {
                Write-RunLog "WHAT-IF: would run: $renewCmd"
                continue
            }

            $renewedCerts = $null
            try {
                $renewedCerts = if ($Force) {
                    Submit-Renewal -AllOrders -Force -ErrorAction Stop
                } else {
                    Submit-Renewal -AllOrders -ErrorAction Stop
                }
            } catch {
                $errMsg = $_.Exception.Message
                # Detect DPAPI decryption failure and surface a clear remediation message.
                if ($errMsg -match 'decrypt|CryptUnprotect|DPAPI|cipher') {
                    Write-RunLog ("Decryption failure for account '$($acct.AccountID)': secure plugin " +
                        'credentials cannot be decrypted under SYSTEM. Run account management in TU-ACME ' +
                        "and use option 'a' to enable portable (AES) encryption.") -Level ERROR
                } else {
                    Write-RunLog "Submit-Renewal failed for account '$($acct.AccountID)': $errMsg" -Level ERROR
                }
                $totalFailed++
                $exitCode = 1
                continue
            }

            $certList = @($renewedCerts | Where-Object { $_ -and $_.Thumbprint })
            if (-not $certList) {
                Write-RunLog "No orders were due for renewal (account $($acct.AccountID))."
                continue
            }

            foreach ($cert in $certList) {
                try {
                    $newTP = $cert.Thumbprint
                    Write-RunLog "Renewed: $($cert.Subject)  thumb=$newTP"

                    # Install renewed cert into the configured store.
                    Install-TUACMECertificate -OrderName $cert.MainDomain -StoreName $resolvedStore
                    Write-RunLog "Installed $newTP into LocalMachine\$resolvedStore"

                    # Rebind: SAN-match preferred (idempotent for headless);
                    # fall back to old-thumbprint match using the pre-renewal snapshot.
                    $sans   = @($cert.AllSANs)
                    if (-not $sans) { $sans = @($cert.MainDomain) }

                    # Derive old thumbprint from the pre-renewal host snapshot so
                    # the value is correct even on retry runs (when the binding may
                    # already carry the new thumbprint in a live IIS query).
                    $oldTP = ''
                    foreach ($san in $sans) {
                        $key = $san.ToLower()
                        if ($hostThumbSnapshot.ContainsKey($key)) { $oldTP = $hostThumbSnapshot[$key]; break }
                    }

                    $res = Update-IISCertificateBinding -Thumbprint $newTP `
                        -HostHeaders $sans -OldThumbprint $oldTP -StoreName $resolvedStore
                    Write-RunLog ("Rebind $($cert.Subject): rebound=$($res.Rebound) failed=$($res.Failed) " +
                        "[SAN-match + thumb-fallback]")
                    Write-TUACMELog -Message ("Runner renewed $($cert.Subject): $oldTP -> $newTP  " +
                        "rebound=$($res.Rebound) failed=$($res.Failed)") -Path $resolvedLogPath

                    $totalRenewed++
                    $totalRebound += $res.Rebound
                    if ($res.Failed -gt 0) { $totalFailed += $res.Failed; $exitCode = 1 }

                    # Post-deploy hook (non-IIS targets).
                    if ($resolvedHook) {
                        if (-not (Test-Path $resolvedHook)) {
                            Write-RunLog "PostDeployHook not found: '$resolvedHook'" -Level WARN
                            $totalFailed++
                            $exitCode = 1
                        } else {
                            try {
                                & $resolvedHook -Certificate $cert -Thumbprint $newTP -StoreName $resolvedStore
                                Write-RunLog "PostDeployHook ran for $newTP via '$resolvedHook'"
                                Write-TUACMELog -Message "PostDeployHook ran for $newTP" -Path $resolvedLogPath
                            } catch {
                                Write-RunLog "PostDeployHook failed for $newTP : $_" -Level ERROR
                                Write-TUACMELog -Level ERROR `
                                    -Message "PostDeployHook failed for $newTP : $_" -Path $resolvedLogPath
                                $totalFailed++
                                $exitCode = 1
                            }
                        }
                    }
                } catch {
                    Write-RunLog "Error processing cert $($cert.Thumbprint): $_" -Level ERROR
                    $totalFailed++
                    $exitCode = 1
                }
            }
        } catch {
            # Per-account isolation: one failed account must not abort the others.
            $errMsg = $_.Exception.Message
            if ($errMsg -match 'decrypt|CryptUnprotect|DPAPI|cipher') {
                Write-RunLog ("Decryption failure for account '$($acct.AccountID)': run account management " +
                    "in TU-ACME to enable portable (AES) encryption (option 'a' in the S menu).") -Level ERROR
            } else {
                Write-RunLog "Unexpected error for account '$($acct.AccountID)': $errMsg" -Level ERROR
            }
            $totalFailed++
            $exitCode = 1
        }
    }
} catch {
    # Fatal setup-level error.
    Write-RunLog "Fatal error: $($_.Exception.Message)" -Level ERROR
    try {
        Write-EventLog -LogName Application -Source 'TU-ACME' -EntryType Error -EventId 2000 `
            -Message "TU-ACME renewal runner fatal error: $($_.Exception.Message)" `
            -ErrorAction SilentlyContinue
    } catch { }
    exit 2
}

# -----------------------------------------------------------------------
# 7. Summary + Event Log.
# -----------------------------------------------------------------------
$summaryMsg = "renewed=$totalRenewed rebound=$totalRebound failed=$totalFailed"
Write-RunLog "====== Summary: $summaryMsg ======"
Write-RunLog "====== TU-ACME Renewal Run End (exit $exitCode) ======"

try {
    if ($exitCode -eq 0) {
        Write-EventLog -LogName Application -Source 'TU-ACME' -EntryType Information -EventId 1000 `
            -Message "TU-ACME renewal run completed successfully. $summaryMsg" `
            -ErrorAction SilentlyContinue
    } else {
        Write-EventLog -LogName Application -Source 'TU-ACME' -EntryType Warning -EventId 1001 `
            -Message "TU-ACME renewal run completed with partial failures. $summaryMsg" `
            -ErrorAction SilentlyContinue
    }
} catch { }

exit $exitCode
