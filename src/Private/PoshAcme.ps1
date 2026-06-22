<#
    PoshAcme.ps1 - Posh-ACME context helpers, server/account resolution, order
    listing, date normalisation, and the Dry-Run / What-If action wrapper.
#>

# Built-in Posh-ACME server aliases that Set-PAServer accepts directly.
$script:PAServerAliases = @(
    'LE_PROD', 'LE_STAGE', 'SSLCOM_RSA', 'SSLCOM_ECC',
    'ZEROSSL_PROD', 'GOOGLE_PROD', 'GOOGLE_STAGE', 'ACTALIS_PROD'
)

function ConvertTo-DateTime {
    <#
        .SYNOPSIS
            Normalises a value that may be a [datetime] or an ISO-8601 string into
            a [datetime] (or $null). RenewAfter/NotAfter vary by Posh-ACME version;
            never call .ToString('fmt') on the raw value.
    #>
    param($Value)
    if ($null -eq $Value -or $Value -eq '') { return $null }
    if ($Value -is [datetime]) { return $Value }
    try { return [datetime]$Value } catch { return $null }
}

function Format-PADate {
    <#
        .SYNOPSIS
            Renders a raw date value (DateTime or ISO-8601 string) as ISO-8601
            'yyyy-MM-dd HH:mm', or '-' when absent/unparseable.
    #>
    param($Value)
    $dt = ConvertTo-DateTime $Value
    if ($null -eq $dt) { return '-' }
    return $dt.ToString('yyyy-MM-dd HH:mm')
}

function ConvertTo-PAServerArg {
    <#
        .SYNOPSIS
            Returns a value Set-PAServer will accept for a given PAServer object.
            Built-in aliases pass directly; custom-named servers must use their
            directory URL (.location).
    #>
    param([Parameter(Mandatory)][object]$Server)
    if ($Server.Name -and ($Server.Name -in $script:PAServerAliases)) { return $Server.Name }
    if ($Server.location) { return $Server.location }
    return $Server.Name
}

function Resolve-PAServerArg {
    <#
        .SYNOPSIS
            Resolves a user-supplied server identifier (alias, custom short name,
            or URL) to a Set-PAServer-compatible value. Aliases and https:// URLs
            pass through; custom short names are looked up in Get-PAServer -List
            and resolved to their .location URL.
    #>
    param([string]$ServerInput)
    if (-not $ServerInput) { return $ServerInput }
    if ($ServerInput -in $script:PAServerAliases) { return $ServerInput }
    if ($ServerInput -match '^https?://') { return $ServerInput }
    try {
        $list  = Get-PAServer -List -ErrorAction Stop
        $match = $list | Where-Object { $_.Name -eq $ServerInput } | Select-Object -First 1
        if ($match -and $match.location) { return $match.location }
    } catch {
        # Fall through and return as-is so Set-PAServer throws a meaningful error.
    }
    return $ServerInput
}

function Convert-PAContactToEmail {
    <#
        .SYNOPSIS
            Extracts the bare email from a Posh-ACME contact ('mailto:a@b' -> 'a@b').
    #>
    param([string]$Contact)
    if (-not $Contact) { return '' }
    if ($Contact -match '^mailto:(.+)$') { return $matches[1] }
    return $Contact
}

function Get-CurrentPAContext {
    <#
        .SYNOPSIS
            Returns the current Posh-ACME server + account (each $null if none).
    #>
    $server  = $null
    $account = $null
    try { $server  = Get-PAServer  -ErrorAction SilentlyContinue } catch { }
    try { $account = Get-PAAccount -ErrorAction SilentlyContinue } catch { }
    return [pscustomobject]@{ Server = $server; Account = $account }
}

function Test-PAAccountNeedsAltEncryption {
    <#
        .SYNOPSIS
            True when an account stores secure plugin args but is not using
            portable (AES) alt encryption - which would fail to decrypt under the
            SYSTEM scheduled task. WebSelfHost has no secure args, so this is a
            no-op for the default HTTP path.
    #>
    param([Parameter(Mandatory)][object]$Account)
    $hasAltKey = $false
    try { $hasAltKey = [bool]$Account.sskey } catch { $hasAltKey = $false }
    $hasSecureArgs = $false
    try {
        if ($Account.PSObject.Properties.Name -contains 'PluginArgsSecured') {
            $hasSecureArgs = [bool]$Account.PluginArgsSecured
        }
    } catch { $hasSecureArgs = $false }
    return ($hasSecureArgs -and -not $hasAltKey)
}

function Get-AllPAAccounts {
    <#
        .SYNOPSIS
            Enumerates every (server, account) tuple known to Posh-ACME on this
            machine. Read-only: restores the previously active server/account.
    #>
    $origServerArg = $null
    $origAccountID = $null
    try {
        $s = Get-PAServer -ErrorAction SilentlyContinue
        if ($s) { $origServerArg = ConvertTo-PAServerArg $s }
    } catch { }
    try {
        $a = Get-PAAccount -ErrorAction SilentlyContinue
        if ($a) { $origAccountID = $a.id }
    } catch { }

    $result  = @()
    $srvList = @()
    try { $srvList = Get-PAServer -List -ErrorAction Stop } catch { return $result }

    foreach ($srv in $srvList) {
        $srvArg = ConvertTo-PAServerArg $srv
        try {
            Set-PAServer $srvArg -ErrorAction Stop | Out-Null
        } catch {
            Write-Info "Could not activate server '$($srv.Name)' for enumeration: $_"
            continue
        }

        $accts = @()
        try { $accts = Get-PAAccount -List -ErrorAction Stop } catch {
            Write-Info "Get-PAAccount -List failed on server '$($srv.Name)': $_"
            continue
        }
        foreach ($a in $accts) {
            $contact = ''
            if ($a.contact) {
                if ($a.contact -is [array]) {
                    $contact = ($a.contact | ForEach-Object { Convert-PAContactToEmail $_ }) -join ';'
                } else {
                    $contact = Convert-PAContactToEmail $a.contact
                }
            }
            $result += [pscustomobject]@{
                ServerName     = $srv.Name
                ServerLoc      = $srv.location
                ServerArg      = $srvArg
                AccountID      = $a.id
                Contact        = $contact
                Status         = $a.status
                KeyAlg         = $a.alg
                KeyLength      = $a.KeyLength
                NeedsAltEncryption = (Test-PAAccountNeedsAltEncryption $a)
                _Raw           = $a
            }
        }
    }

    if ($origServerArg) {
        try { Set-PAServer $origServerArg -ErrorAction SilentlyContinue | Out-Null } catch { }
    }
    if ($origAccountID) {
        try { Set-PAAccount -ID $origAccountID -ErrorAction SilentlyContinue | Out-Null } catch { }
    }
    return $result
}

function Get-PAOrdersList {
    <#
        .SYNOPSIS
            Returns all Posh-ACME orders on the current server, normalised.
    #>
    try {
        $orders = Get-PAOrder -List -Refresh -ErrorAction Stop
    } catch {
        Write-Info "Get-PAOrder failed: $_"
        return @()
    }
    $result = @()
    foreach ($o in $orders) {
        $cert = $null
        try { $cert = $o | Get-PACertificate -ErrorAction SilentlyContinue } catch { }
        $result += [pscustomobject]@{
            Name        = $o.Name
            MainDomain  = $o.MainDomain
            Identifiers = (($o.Identifiers | ForEach-Object { $_.Value }) -join ',')
            Status      = $o.Status
            CertThumb   = if ($cert) { $cert.Thumbprint } else { '' }
            NotAfter    = if ($cert) { $cert.NotAfter } else { $null }
            RenewAfter  = $o.RenewAfter
            Location    = $o.location
        }
    }
    return $result
}

function Get-PAInvalidOrdersForIdentifiers {
    <#
        .SYNOPSIS
            Returns orders in 'invalid' state whose identifiers overlap the
            requested set. Such orders block re-issue and must be removed first.
    #>
    param([Parameter(Mandatory)][string[]]$Identifiers)
    $wanted = $Identifiers | ForEach-Object { $_.ToLower() }
    $orders = Get-PAOrdersList
    return @($orders | Where-Object {
        $_.Status -ieq 'invalid' -and
        @($_.Identifiers -split ',' | Where-Object { $_.ToLower() -in $wanted }).Count -gt 0
    })
}

function Invoke-PAAction {
    <#
        .SYNOPSIS
            Runs (or simulates) a Posh-ACME / state-changing action.
            - Dry-Run:  prints the equivalent command, executes nothing.
            - What-If:  calls the scriptblock with -WhatIf (best effort).
            - Otherwise: invokes the scriptblock.
    #>
    param(
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][scriptblock]$Action,
        [Parameter(Mandatory)][string]$DryRunCommand,
        [switch]$NoWhatIf
    )
    Write-Host ''
    Write-Host "==> $Description" -ForegroundColor Cyan

    if ($script:DryRun) {
        Write-Warn 'DRY-RUN: no changes will be made.'
        Write-Host '  Equivalent command:' -ForegroundColor DarkCyan
        Write-Host "  $DryRunCommand" -ForegroundColor Gray
        return $null
    }

    if ($script:WhatIf -and -not $NoWhatIf) {
        Write-Warn 'WHAT-IF: passing -WhatIf to underlying cmdlet where supported.'
        try {
            & $Action -WhatIf
        } catch {
            Write-Info "Command rejected -WhatIf: $_ -- showing simulated command."
            Write-Host "  $DryRunCommand" -ForegroundColor Gray
        }
        return $null
    }

    return (& $Action)
}
