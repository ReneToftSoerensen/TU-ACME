<#
.SYNOPSIS
    Non-interactive renewal + IIS re-bind script for Posh-ACME.
    Intended to be invoked by a Windows Scheduled Task registered via PoshAcmeTui.ps1.

.DESCRIPTION
    1. Activates the ACME server + account passed via -ServerName / -AccountID
       (or uses whatever is currently active if neither is supplied).
    2. Snapshots the current thumbprint of every existing PAOrder on that server.
    3. Calls Submit-Renewal -RenewAll (Posh-ACME renews only orders whose
       RenewAfter <= now, so daily/weekly runs are safe).
    4. For every order whose thumbprint changed, finds all IIS HTTPS bindings
       using the OLD thumbprint and re-points them to the NEW thumbprint
       (preserving SslFlags).
    5. Writes a structured log to $LogPath (default C:\ProgramData\PoshTUI\renewal.log).

    Exit codes:
        0 = success
        1 = renewal or rebind had at least one error (see log)
        2 = preflight failure (cannot access Posh-ACME / IIS)

.PARAMETER ServerName
    Optional Posh-ACME server name (e.g. 'LE_PROD' or a custom URL).
    If omitted, the currently active server is used.

.PARAMETER AccountID
    Optional Posh-ACME account ID to activate before renewal.
    If omitted, the currently active account is used.

.PARAMETER LogPath
    Log file path. Default: C:\ProgramData\PoshTUI\renewal.log

.EXAMPLE
    pwsh -NoProfile -ExecutionPolicy Bypass -File .\PoshAcme-Renew.ps1
    pwsh -NoProfile -ExecutionPolicy Bypass -File .\PoshAcme-Renew.ps1 -ServerName LE_PROD -AccountID abc123
#>

#Requires -Version 7.0
#Requires -Modules Posh-ACME, IISAdministration

param(
    [string]$ServerName,
    [string]$AccountID,
    [string]$LogPath = 'C:\ProgramData\PoshTUI\renewal.log'
)

# ============================================================
# SHARED POSH-ACME HOME
# ============================================================
# PoshTUI uses a shared Posh-ACME data store so that the interactive admin
# user AND the SYSTEM account (used by scheduled renewal tasks) see the same
# accounts/servers/orders/certs. The TUI sets POSHACME_HOME machine-wide on
# first run; we re-affirm it here as belt-and-suspenders in case the machine
# env var is missing (e.g. task ran before the TUI was first launched).
$sharedHome = 'C:\ProgramData\PoshTUI\ACME'
if (-not (Test-Path $sharedHome)) {
    try { New-Item -ItemType Directory -Path $sharedHome -Force | Out-Null } catch {}
}
# Always set the process-level value; do NOT touch the Machine scope from here
# (the TUI owns that).
$env:POSHACME_HOME = $sharedHome

# ============================================================
# LOGGING
# ============================================================

function Write-Log {
    param([string]$Level, [string]$Message)
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "$ts [$Level] $Message"
    if ($Level -eq 'ERROR') { Write-Host $line -ForegroundColor Red }
    elseif ($Level -eq 'WARN')  { Write-Host $line -ForegroundColor Yellow }
    elseif ($Level -eq 'OK')    { Write-Host $line -ForegroundColor Green }
    else                        { Write-Host $line }
    try {
        $dir = Split-Path $LogPath -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Add-Content -Path $LogPath -Value $line -Encoding UTF8
    } catch {
        Write-Host "WARN: Could not append to log $LogPath : $_" -ForegroundColor Yellow
    }
}

# ============================================================
# IIS BINDING UTILITIES
# ============================================================

function Get-IISSslBindings {
    $mgr = Get-IISServerManager
    foreach ($site in $mgr.Sites) {
        foreach ($b in $site.Bindings) {
            if ($b.Protocol -ine 'https') { continue }
            $parts = $b.bindingInformation -split ':', 3
            $ip      = if ($parts[0]) { $parts[0] } else { '*' }
            $port    = if ($parts[1]) { $parts[1] } else { '443' }
            $hostHdr = if ($parts.Count -ge 3 -and $parts[2]) { $parts[2] } else { '' }
            $certHash = if ($b.CertificateHash) {
                ([System.BitConverter]::ToString($b.CertificateHash)).Replace('-', '').ToLower()
            } else { '' }
            [PSCustomObject]@{
                SiteName          = $site.Name
                BindingInformation = $b.bindingInformation
                IPAddress         = $ip
                Port              = $port
                HostHeader        = $hostHdr
                Thumbprint        = $certHash
                CertStore         = $b.CertificateStore
            }
        }
    }
}

function Get-IISBindingsByThumbprint {
    param([string]$Thumbprint)
    if (-not $Thumbprint) { return @() }
    $tp = $Thumbprint.ToLower()
    Get-IISSslBindings | Where-Object { $_.Thumbprint -and $_.Thumbprint.ToLower() -eq $tp }
}

function Set-IISBindingCertificate {
    param(
        [string]$SiteName,
        [string]$BindingInformation,
        [string]$Thumbprint,
        [string]$StoreName = 'WebHosting'
    )
    $mgr = Get-IISServerManager
    $site = $mgr.Sites[$SiteName]
    if (-not $site) { throw "Site '$SiteName' not found." }
    $binding = $site.Bindings | Where-Object {
        $_.BindingInformation -eq $BindingInformation -and $_.Protocol -ieq 'https'
    } | Select-Object -First 1
    if (-not $binding) { throw "HTTPS binding '$BindingInformation' not found on '$SiteName'." }

    $hashBytes = [byte[]]::new($Thumbprint.Length / 2)
    for ($i = 0; $i -lt $hashBytes.Length; $i++) {
        $hashBytes[$i] = [Convert]::ToByte($Thumbprint.Substring($i * 2, 2), 16)
    }
    $binding.CertificateHash  = $hashBytes
    $binding.CertificateStore = $StoreName
    $mgr.CommitChanges()
}

# ============================================================
# MAIN
# ============================================================

$exitCode = 0
Write-Log 'INFO' '====== PoshTUI Renewal Run ======'
Write-Log 'INFO' "LogPath: $LogPath"

# ---- Activate server/account if specified ----
if ($ServerName) {
    # Resolve the input to a Set-PAServer-compatible argument.
    # Built-in aliases (LE_PROD, LE_STAGE, etc.) pass through. Full URLs pass through.
    # Custom short names like 'acme.fragt.root.local' are converted to the matching
    # server's location URL via Get-PAServer -List.
    $srvArg = $ServerName
    $builtins = @('LE_PROD','LE_STAGE','SSLCOM_RSA','SSLCOM_ECC','ZEROSSL_PROD','GOOGLE_PROD','GOOGLE_STAGE','ACTALIS_PROD')
    if ($ServerName -notin $builtins -and $ServerName -notmatch '^https?://') {
        try {
            $match = Get-PAServer -List -ErrorAction Stop | Where-Object { $_.Name -eq $ServerName } | Select-Object -First 1
            if ($match -and $match.location) { $srvArg = $match.location }
        } catch {
            Write-Log 'WARN' "Could not enumerate PAServer list to resolve '$ServerName'; passing as-is."
        }
    }
    try {
        Set-PAServer $srvArg -ErrorAction Stop | Out-Null
        Write-Log 'OK' "Activated server: $ServerName$(if ($srvArg -ne $ServerName) { " (via $srvArg)" })"
    } catch {
        Write-Log 'ERROR' "Cannot activate server '$ServerName' (arg='$srvArg'): $_"
        exit 2
    }
}
if ($AccountID) {
    try {
        Set-PAAccount -ID $AccountID -ErrorAction Stop | Out-Null
        Write-Log 'OK' "Activated account: $AccountID"
    } catch {
        Write-Log 'ERROR' "Cannot activate account '$AccountID': $_"
        exit 2
    }
}

# ---- Snapshot pre-renewal thumbprints ----
$orders = @()
try {
    $orders = Get-PAOrder -List -Refresh -ErrorAction Stop
} catch {
    Write-Log 'ERROR' "Get-PAOrder -List failed: $_"
    exit 2
}

$thumbprintBefore = @{}
foreach ($o in $orders) {
    $cert = $null
    try { $cert = $o | Get-PACertificate -ErrorAction Stop } catch {}
    if ($cert -and $cert.Thumbprint) {
        $thumbprintBefore[$o.Name] = $cert.Thumbprint
        Write-Log 'INFO' "Pre-renewal: order '$($o.MainDomain)' thumb=$($cert.Thumbprint)"
    } else {
        Write-Log 'WARN' "Pre-renewal: order '$($o.MainDomain)' has no cert thumbprint; will not rebind"
    }
}

if (-not $thumbprintBefore.Count) {
    Write-Log 'INFO' 'No orders with certificates to renew. Done.'
    Write-Log 'INFO' '====== End of run (exit 0) ======'
    exit 0
}

# ---- Submit renewal for all due orders ----
Write-Log 'INFO' 'Submitting Submit-Renewal -RenewAll ...'
try {
    Submit-Renewal -RenewAll -ErrorAction Stop
    Write-Log 'OK' 'Submit-Renewal completed.'
} catch {
    Write-Log 'ERROR' "Submit-Renewal failed: $_"
    $exitCode = 1
    # Continue to rebind step anyway — some orders may have renewed before the error
}

# ---- Re-bind IIS bindings using pre-renewal thumbprints ----
Write-Log 'INFO' '------ IIS re-bind phase ------'
$renewed = @()
try { $renewed = Get-PAOrder -List -Refresh -ErrorAction Stop } catch {
    Write-Log 'ERROR' "Get-PAOrder -List (post-renewal) failed: $_"
    exit $exitCode
}

$okCount = 0; $failCount = 0; $skipCount = 0
foreach ($ro in $renewed) {
    if (-not $thumbprintBefore.ContainsKey($ro.Name)) { continue }
    $oldTP = $thumbprintBefore[$ro.Name]

    $newCert = $null
    try { $newCert = (Get-PAOrder -Name $ro.Name) | Get-PACertificate -ErrorAction Stop } catch {}
    if (-not $newCert -or -not $newCert.Thumbprint) {
        Write-Log 'WARN' "Post-renewal: order '$($ro.MainDomain)' has no cert; cannot rebind"
        $skipCount++
        continue
    }
    $newTP = $newCert.Thumbprint

    if ($newTP -ieq $oldTP) {
        Write-Log 'INFO' "Order '$($ro.MainDomain)': thumbprint unchanged ($newTP), no rebind needed"
        $skipCount++
        continue
    }

    Write-Log 'INFO' "Order '$($ro.MainDomain)': $oldTP -> $newTP"
    $bindings = Get-IISBindingsByThumbprint -Thumbprint $oldTP
    if (-not $bindings) {
        Write-Log 'INFO' "  No IIS HTTPS bindings using old thumbprint $oldTP"
        continue
    }
    foreach ($b in $bindings) {
        try {
            Set-IISBindingCertificate -SiteName $b.SiteName -BindingInformation $b.BindingInformation `
                -Thumbprint $newTP -StoreName 'WebHosting'
            Write-Log 'OK' "  Rebound: $($b.SiteName) / $($b.BindingInformation)"
            $okCount++
        } catch {
            Write-Log 'ERROR' "  Failed to rebind $($b.SiteName) / $($b.BindingInformation): $_"
            $failCount++
            $exitCode = 1
        }
    }
}

Write-Log 'INFO' "Summary: rebound OK=$okCount  failed=$failCount  skipped=$skipCount"
Write-Log 'INFO' "====== End of run (exit $exitCode) ======"
exit $exitCode
