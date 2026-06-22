<#
.SYNOPSIS
    PoshTUI - A Text User Interface for Posh-ACME on Windows (PowerShell 7).
    Looks and feels like Simple ACME (WACS).

.DESCRIPTION
    Interactive TUI that wraps the Posh-ACME module to:
      - Create new Let's Encrypt certificates with full IIS integration
      - Renew individual certificates or run all renewals in batch
      - Manage renewal orders (list / inspect / revoke / delete)
      - Browse IIS bindings and the certificates bound to them
      - Toggle Dry-Run mode (no cert generated, just show equivalent commands)
      - Toggle What-If mode (Posh-ACME -WhatIf where supported)

    Multi-host certificate requests are supported via Simple-ACME style filters
    (site IDs, host patterns, regex, manual toggle). The IIS binding picker is
    reused from the original test1.ps1.

    On renewal, every IIS HTTPS binding that was using the previous certificate
    thumbprint is re-bound to the new certificate thumbprint, so SSL bindings
    keep working across renewals without manual intervention.

.NOTES
    Requirements:
      - Windows Server 2016+ / Windows 10+ with IIS installed
      - PowerShell 7.0 or later
      - Run as Administrator
      - Modules: Posh-ACME (>= 4.x), IISAdministration

    Author: PoshTUI
    Example:
        pwsh -File .\PoshAcmeTui.ps1
#>

#Requires -RunAsAdministrator
#Requires -Version 7.0
#Requires -Modules Posh-ACME, IISAdministration

# ============================================================
# SCRIPT STATE
# ============================================================

$script:DryRun = $false
$script:WhatIf = $false

# System-wide install location. Both config.json AND the shared Posh-ACME data
# store live here so that the interactive user (Administrator) and the scheduled
# task (running as SYSTEM) see the same accounts, servers, orders, and certs.
$script:ProgramDataDir = 'C:\ProgramData\PoshTUI'
$script:ConfigFile     = Join-Path $script:ProgramDataDir 'config.json'
$script:SharedACMEHome = Join-Path $script:ProgramDataDir 'ACME'

# Expected location of the Posh-ACME module when installed with -Scope AllUsers.
$script:ExpectedPAmeModulePath = 'C:\Program Files\WindowsPowerShell\Modules\Posh-ACME'

# Default configuration. Persisted to $script:ConfigFile (system-wide) on first save.
$script:Config = [ordered]@{
    ACMEServer        = 'LE_PROD'        # LE_PROD | LE_STAGE | custom URL
    ContactEmail      = ''
    KeyType           = 'EC'             # RSA | EC
    KeyLength         = 256              # 2048/3072/4096 for RSA, 256/384 for EC
    ValidationPlugin  = 'WebSelfHost'    # WebSelfHost (HTTP-01 via IIS) | DNS plugin name
    DnsPluginArgs     = @{}              # plugin args for DNS-01
    CertStore         = 'WebHosting'     # where to import the cert
    RenewalDaysBefore = 30               # renew when <= 30 days left
}

# ============================================================
# STARTUP PREREQUISITES
# ============================================================

function Assert-PoshACMEModuleInstalled {
    <#
        .SYNOPSIS
            Verifies that Posh-ACME is installed at the expected AllUsers location
            (C:\Program Files\WindowsPowerShell\Modules\Posh-ACME). If not, prints
            a clear error and exits.
    #>
    $expected = $script:ExpectedPAmeModulePath
    if (-not (Test-Path $expected)) {
        Write-Host ''
        Write-Host '============================================================' -ForegroundColor Red
        Write-Host ' Posh-ACME module not found at expected location' -ForegroundColor Red
        Write-Host '============================================================' -ForegroundColor Red
        Write-Host ''
        Write-Host "Expected: $expected" -ForegroundColor Yellow
        Write-Host ''
        Write-Host 'PoshTUI assumes Posh-ACME is installed for All Users so that both' -ForegroundColor White
        Write-Host 'the interactive administrator and the SYSTEM account (used by scheduled' -ForegroundColor White
        Write-Host 'renewal tasks) can load the module from the same path.' -ForegroundColor White
        Write-Host ''
        Write-Host 'Install it with:' -ForegroundColor Cyan
        Write-Host '  Install-Module -Name Posh-ACME -Scope AllUsers -Force' -ForegroundColor White
        Write-Host ''
        Write-Host 'Then re-launch PoshTUI.' -ForegroundColor White
        Write-Host ''
        exit 1
    }

    # Also confirm the module actually loads (catches broken installs).
    try {
        Import-Module Posh-ACME -ErrorAction Stop
    } catch {
        Write-Host ''
        Write-Host '============================================================' -ForegroundColor Red
        Write-Host ' Posh-ACME module failed to import' -ForegroundColor Red
        Write-Host '============================================================' -ForegroundColor Red
        Write-Host ''
        Write-Host "Module folder exists at $expected but Import-Module threw:" -ForegroundColor Yellow
        Write-Host "  $_" -ForegroundColor White
        Write-Host ''
        Write-Host 'Reinstall with: Install-Module -Name Posh-ACME -Scope AllUsers -Force' -ForegroundColor Cyan
        Write-Host ''
        exit 1
    }
}

function Ensure-ProgramDataDir {
    <#
        .SYNOPSIS
            Creates C:\ProgramData\PoshTUI and the shared ACME data folder if
            missing, and applies the ACL:
              Administrators : FullControl
              SYSTEM         : FullControl
              Users          : ReadAndExecute (so config.json is readable by all)
    #>
    $dirs = @($script:ProgramDataDir, $script:SharedACMEHome)
    foreach ($d in $dirs) {
        if (-not (Test-Path $d)) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
        }
    }

    # ACL: Administrators + SYSTEM = Full, Users = ReadAndExecute, inherit to children.
    $acl = Get-Acl $script:ProgramDataDir
    $acl.SetAccessRuleProtection($false, $false)  # inherit from parent

    # Remove existing explicit rules (in case of re-runs) and add fresh ones
    $acl.Access | Where-Object { -not $_.IsInherited } | ForEach-Object {
        $acl.RemoveAccessRule($_) | Out-Null
    }

    $rights = @(
        (New-Object Security.AccessControl.FileSystemAccessRule(
            'BUILTIN\Administrators', 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')),
        (New-Object Security.AccessControl.FileSystemAccessRule(
            'NT AUTHORITY\SYSTEM', 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')),
        (New-Object Security.AccessControl.FileSystemAccessRule(
            'BUILTIN\Users', 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
    )
    foreach ($r in $rights) { $acl.AddAccessRule($r) }

    Set-Acl -Path $script:ProgramDataDir -AclObject $acl
    # Sub-directories inherit the same ACL by default.
}

function Ensure-SharedPoshAcmeHome {
    <#
        .SYNOPSIS
            Sets the machine-wide POSHACME_HOME environment variable to the
            shared location, so that both the interactive user and SYSTEM see
            the same Posh-ACME accounts/servers/orders/certs. Also sets it for
            the current process so no relaunch is needed.
    #>
    $shared = $script:SharedACMEHome
    $current = [Environment]::GetEnvironmentVariable('POSHACME_HOME', 'Machine')
    if ($current -ne $shared) {
        try {
            [Environment]::SetEnvironmentVariable('POSHACME_HOME', $shared, 'Machine')
        } catch {
            Write-Host "WARN: Could not set machine-wide POSHACME_HOME: $_" -ForegroundColor Yellow
        }
    }
    # Current process needs the value too (env vars set at Machine scope don't
    # propagate to running processes until next launch).
    $env:POSHACME_HOME = $shared
}

function Invoke-PoshAcmeDataMigration {
    <#
        .SYNOPSIS
            One-time migration: if the user has an existing ~/.poshacme folder
            AND the shared location is empty, copy the contents over. The
            original is left intact for rollback safety.
    #>
    $userHome = Join-Path $HOME '.poshacme'
    $shared   = $script:SharedACMEHome

    if (-not (Test-Path $userHome)) { return $false }

    # Is the user's store non-empty?
    $userItems = Get-ChildItem -Path $userHome -Force -ErrorAction SilentlyContinue
    if (-not $userItems) { return $false }

    # Is the shared store empty?
    $sharedItems = Get-ChildItem -Path $shared -Force -ErrorAction SilentlyContinue
    if ($sharedItems) { return $false }  # shared already has data, don't overwrite

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ' One-time Posh-ACME data migration' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Existing Posh-ACME data was found in your user profile:" -ForegroundColor White
    Write-Host "  $userHome" -ForegroundColor Yellow
    Write-Host ''
    Write-Host "To make this data visible to both your account and the SYSTEM account" -ForegroundColor White
    Write-Host "(used by scheduled renewal tasks), it will be copied to the shared location:" -ForegroundColor White
    Write-Host "  $shared" -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Your original data will be left intact so you can roll back if needed.' -ForegroundColor DarkGray
    Write-Host ''
    $ans = Read-Host 'Migrate now? [Y/n]'
    if ($ans.Trim().ToLower() -eq 'n') {
        Write-Host 'Migration skipped. Posh-ACME will use the shared location from now on.' -ForegroundColor Yellow
        Write-Host 'Your existing data at ~/.poshacme will not be visible to the TUI. Re-run to migrate.' -ForegroundColor Yellow
        Pause-UI
        return $false
    }

    try {
        Copy-Item -Path (Join-Path $userHome '*') -Destination $shared -Recurse -Force -ErrorAction Stop
        Write-Host ''
        Write-Host "OK: copied $($userItems.Count) item(s) to $shared" -ForegroundColor Green
        Write-Host "Original left at: $userHome" -ForegroundColor DarkGray
        Pause-UI
        return $true
    } catch {
        Write-Host ''
        Write-Host "ERR: Migration failed: $_" -ForegroundColor Red
        Write-Host 'The shared location may be in an inconsistent state. Inspect manually.' -ForegroundColor Red
        Pause-UI
        return $false
    }
}

# ============================================================
# BANNER & UI HELPERS
# ============================================================

function Show-Banner {
    $banner = @'
  ____            _     _____         _      _    ___
 |  _ \ ___ _ __ | |_  |_   _|_ _ ___| | __ | |  / _ \ _ __ ___
 | |_) / _ \ '_ \| __|   | |/ _` / __| |/ / | |  | | | | '_ ` _ \
 |  __/  __/ | | | |_    | | (_| \__ \   <  | |__| |_| | | | | | |
 |_|   \___|_| |_|\__|   |_|\__,_|___/_|\_\ |_____\___/|_| |_| |_|
  A Text User Interface for POSH ACME on Windows (PowerShell 7)
'@
    Clear-Host
    Write-Host $banner -ForegroundColor Cyan
    Write-Host ''
}

function Write-Sep {
    param([string]$Title = '', [int]$Width = 108)
    if ($Title) {
        $line = ('-' * (($Width - $Title.Length - 2) / 2))
        Write-Host ("{0} {1} {0}" -f $line, $Title) -ForegroundColor DarkCyan
    } else {
        Write-Host ('-' * $Width) -ForegroundColor DarkCyan
    }
}

function Write-Step {
    param([string]$Text)
    Write-Host ''
    Write-Host $Text -ForegroundColor Cyan
    Write-Sep
}

function Write-Ok    { param([string]$m) Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn  { param([string]$m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err   { param([string]$m) Write-Host "[ERR]  $m" -ForegroundColor Red }
function Write-Info  { param([string]$m) Write-Host "[i]    $m" -ForegroundColor DarkGray }

function Read-MenuChoice {
    param(
        [string]$Prompt = 'Choice',
        [string[]]$ValidKeys = @()
    )
    while ($true) {
        $line = Read-Host $Prompt
        if (-not $line) { continue }
        $key = $line.Trim().ToUpper()
        if ($ValidKeys -and ($key -notin $ValidKeys)) {
            Write-Warn "Invalid choice. Valid: $($ValidKeys -join ', ')"
            continue
        }
        return $key
    }
}

function Confirm-Prompt {
    param([string]$Prompt = 'Confirm?', [switch]$DefaultYes)
    $hint = if ($DefaultYes) { '[Y/n]' } else { '[y/N]' }
    $ans = Read-Host "$Prompt $hint"
    if ($DefaultYes) { return $ans.Trim().ToLower() -ne 'n' }
    return $ans.Trim().ToLower() -eq 'y'
}

function Pause-UI {
    param([string]$Msg = 'Press Enter to continue...')
    Read-Host $Msg | Out-Null
}

# ============================================================
# CONFIG LOAD / SAVE
# ============================================================

function Save-Config {
    $dir = Split-Path $script:ConfigFile -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $script:Config | ConvertTo-Json -Depth 6 | Set-Content -Path $script:ConfigFile -Encoding UTF8
}

function Load-Config {
    if (Test-Path $script:ConfigFile) {
        try {
            $json = Get-Content $script:ConfigFile -Raw | ConvertFrom-Json -AsHashtable
            foreach ($k in $json.Keys) { $script:Config[$k] = $json[$k] }
        } catch {
            Write-Warn "Could not load config from $($script:ConfigFile): $_"
        }
    } else {
        Save-Config
    }
}

# ============================================================
# IIS HELPER FUNCTIONS  (ported from test1.ps1)
# ============================================================

function Get-IISBindingsRaw {
    $mgr = Get-IISServerManager
    foreach ($site in $mgr.Sites) {
        foreach ($b in $site.Bindings) {
            $parts = $b.bindingInformation -split ':', 3
            $ip        = if ($parts[0]) { $parts[0] } else { '*' }
            $port      = if ($parts[1]) { $parts[1] } else { '80' }
            $hostHdr   = if ($parts.Count -ge 3 -and $parts[2]) { $parts[2] } else { '' }
            $certHash  = if ($b.CertificateHash) {
                ([System.BitConverter]::ToString($b.CertificateHash)).Replace('-', '').ToLower()
            } else { '' }
            $certStore = $b.CertificateStore

            [PSCustomObject]@{
                SiteName       = $site.Name
                SiteID         = $site.Id
                Protocol       = $b.Protocol
                IPAddress      = $ip
                Port           = $port
                HostHeader     = $hostHdr
                CertificateHash   = $certHash
                CertificateStore  = $certStore
                SslFlags        = [string]$b.SslFlags
            }
        }
    }
}

function ConvertTo-WacsFilter {
    param([string]$Raw)
    if (-not $Raw) { return @() }
    $Raw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
}

function Test-WacsHostPattern {
    param([string]$Value, [string[]]$Patterns)
    foreach ($p in $Patterns) {
        $escaped = [regex]::Escape($p)
        $pattern = $escaped -replace '\\\*', '.*'
        $pattern = $pattern -replace '\\\?', '.'
        if ($Value -match ('^' + $pattern + '$')) { return $true }
    }
    return $false
}

function Get-IISFilteredSites {
    param([string]$SiteFilter)
    $mgr = Get-IISServerManager
    $all = foreach ($s in $mgr.Sites) {
        [PSCustomObject]@{ Id = $s.Id; Name = $s.Name; State = $s.State; _RawObject = $s }
    }
    if (-not $SiteFilter) { return $all }
    $filter = ConvertTo-WacsFilter $SiteFilter
    if ($filter -contains 's') { return $all }
    $ids = $filter | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
    if ($ids) { return $all | Where-Object { $_.Id -in $ids } }
    return @()
}

# ============================================================
# IIS BINDING PICKERS  (ported from test1.ps1, lightly adapted)
# ============================================================

function Select-IISSitesUI {
    $selectedSites = $null
    $choice = 'a'
    while ($choice -ne 'c') {
        Clear-Host
        Write-Step 'Step 1: Select IIS Sites'
        Write-Host '   * = Selected'
        Write-Host ''

        $currentSites = @()
        try {
            $mgr = Get-IISServerManager
            $selIds = if ($selectedSites) { $selectedSites.Id } else { @() }
            foreach ($site in $mgr.Sites) {
                $marker = if ($site.Id -in $selIds) { '*' } else { ' ' }
                $currentSites += [PSCustomObject]@{
                    Selected = $marker
                    Id       = $site.Id
                    Name     = $site.Name
                    State    = [string]$site.State
                    _RawObject = $site
                }
            }
        } catch {
            Write-Err "Error accessing IIS: $_"
        }

        if ($currentSites) {
            $table = $currentSites | Sort-Object Id |
                Select-Object Selected, Id, Name, State |
                Format-Table -AutoSize | Out-String
            if ([string]::IsNullOrWhiteSpace($table)) { $currentSites | Format-List }
            else { Write-Host $table }
        } else {
            Write-Warn 'No IIS Sites found on this server.'
        }

        Write-Host ''
        Write-Host 'Options:' -ForegroundColor Cyan
        Write-Host "  s <filter>   Filter by site IDs (e.g. 's 1,3') or 's s' for all sites"
        Write-Host '  c            Confirm selection & continue to bindings'
        Write-Host '  x            Cancel'

        $line = Read-Host 'Command'
        if (-not $line) { continue }
        $parts = $line -split '\s+', 2
        $cmd   = $parts[0]
        $arg   = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }

        switch ($cmd) {
            's' {
                if (-not $arg) { Write-Warn "Provide a filter (e.g. 's 1,3' or 's s')."; Pause-UI; continue }
                $temp = Get-IISFilteredSites $arg
                if (-not $temp) { Write-Warn 'No sites match that filter.'; Pause-UI; continue }
                $selectedSites = $temp
            }
            'c' {
                if (-not $selectedSites) {
                    Write-Warn 'No sites selected yet; defaulting to ALL sites.'
                    Start-Sleep -Seconds 1
                    $mgr = Get-IISServerManager
                    return @(foreach ($s in $mgr.Sites) {
                        [PSCustomObject]@{ Id = $s.Id; Name = $s.Name; State = [string]$s.State; _RawObject = $s }
                    })
                }
                return $selectedSites
            }
            'x' { throw 'Cancelled by user.' }
            default { Write-Warn 'Unknown command. Use s/c/x.'; Pause-UI }
        }
    }
}

function Select-IISBindingsUI {
    param([Parameter(ValueFromPipeline=$true)][object[]]$Sites)
    begin { $collected = @() }
    process { if ($null -ne $_) { $collected += $_ } }
    end {
        if (-not $collected) {
            $mgr = Get-IISServerManager
            $collected = @(foreach ($s in $mgr.Sites) {
                [PSCustomObject]@{ Id = $s.Id; Name = $s.Name; State = [string]$s.State; _RawObject = $s }
            })
        }

        $hostPatterns = @()
        $hostRegex    = $null
        $manual       = $null
        $choice = 'a'

        while ($choice -ne 'c') {
            Clear-Host
            Write-Step 'Step 2: Filter Host Headers'
            Write-Host "Sites Included: $($collected.Name -join ', ')"
            Write-Host ''

            $raw = Get-IISBindingsRaw | Where-Object {
                $_.SiteName -in $collected.Name -and
                $_.HostHeader -ne '' -and
                $_.HostHeader -ne '*'
            }

            $filtered = $raw
            if ($hostPatterns) { $filtered = $filtered | Where-Object { Test-WacsHostPattern $_.HostHeader $hostPatterns } }
            if ($hostRegex)    { $filtered = $filtered | Where-Object { $_.HostHeader -match $hostRegex } }

            $display = @()
            $i = 0
            foreach ($b in $filtered) {
                $i++
                $mark = if ($null -eq $manual -or $b.HostHeader -in $manual) { '*' } else { ' ' }
                $display += [PSCustomObject]@{
                    Idx        = $i
                    Selected   = $mark
                    SiteName   = $b.SiteName
                    Protocol   = $b.Protocol
                    IPAddress  = $b.IPAddress
                    Port       = $b.Port
                    HostHeader = $b.HostHeader
                }
            }

            if ($display) {
                $table = $display | Select-Object Idx, Selected, SiteName, Protocol, IPAddress, Port, HostHeader |
                    Format-Table -AutoSize | Out-String
                if ([string]::IsNullOrWhiteSpace($table)) { $display | Format-List }
                else { Write-Host $table }
            } else {
                Write-Warn 'No matching bindings.'
            }

            Write-Host ''
            Write-Host 'Active Filters:' -ForegroundColor Yellow
            if ($hostPatterns) { Write-Host "  Pattern: $($hostPatterns -join ',')" }
            if ($hostRegex)    { Write-Host "  Regex  : $hostRegex" }
            if (-not $hostPatterns -and -not $hostRegex) { Write-Host '  None (showing all)' }
            if ($null -ne $manual) {
                Write-Host "  Manual Selection: Enabled ($($manual.Count) selected)" -ForegroundColor Cyan
            }

            Write-Host ''
            Write-Host 'Options:' -ForegroundColor Cyan
            Write-Host "  p <pattern>   Filter by host pattern (e.g. 'p example.*')"
            Write-Host "  r <regex>     Filter by host regex (e.g. 'r ^.*\.contoso\.com$')"
            Write-Host "  s <number>    Toggle specific binding (e.g. 's 2')"
            Write-Host '  clear         Reset all filters and selections'
            Write-Host '  c             Confirm selection & continue to CN selection'
            Write-Host '  x             Cancel'

            $line = Read-Host 'Command'
            if (-not $line) { continue }
            $parts = $line -split '\s+', 2
            $cmd   = $parts[0]
            $arg   = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }

            switch ($cmd) {
                'p' {
                    if (-not $arg) { Write-Warn 'Provide a pattern.'; Pause-UI; continue }
                    $hostPatterns = ConvertTo-WacsFilter $arg
                    $hostRegex    = $null
                    $manual       = $null
                }
                'r' {
                    if (-not $arg) { Write-Warn 'Provide a regex.'; Pause-UI; continue }
                    try { $null = [regex]::new($arg); $hostRegex = $arg }
                    catch { Write-Warn 'Invalid regex.'; Pause-UI; continue }
                    $hostPatterns = @()
                    $manual       = $null
                }
                's' {
                    if (-not $arg -or $arg -notmatch '^\d+$') { Write-Warn "Provide a number (e.g. 's 2')."; Pause-UI; continue }
                    $idx = [int]$arg
                    $target = $display | Where-Object { $_.Idx -eq $idx }
                    if (-not $target) { Write-Warn 'Number out of range.'; Pause-UI; continue }
                    if ($null -eq $manual) { $manual = @($display | Select-Object -ExpandProperty HostHeader) }
                    if ($target.HostHeader -in $manual) {
                        $manual = @($manual | Where-Object { $_ -ne $target.HostHeader })
                        Write-Host "Deselected: $($target.HostHeader)"
                    } else {
                        $manual += $target.HostHeader
                        Write-Host "Selected: $($target.HostHeader)"
                    }
                    Pause-UI
                }
                'clear' {
                    $hostPatterns = @()
                    $hostRegex    = $null
                    $manual       = $null
                    Write-Host 'Filters and selections reset.'
                    Pause-UI
                }
                'c' {
                    if ($null -eq $manual) {
                        $final = @($filtered | Select-Object -ExpandProperty HostHeader -Unique)
                    } else {
                        $final = @($manual)
                    }
                    if (-not $final) {
                        Write-Warn "No bindings selected. Press 'c' again to continue empty or 'clear' to reset."
                        Pause-UI
                    } else {
                        return $final
                    }
                }
                'x' { throw 'Cancelled by user.' }
                default { Write-Warn 'Unknown command. Use p/r/s/clear/c/x.'; Pause-UI }
            }
        }
    }
}

function Select-IISCommonNameUI {
    param([Parameter(ValueFromPipeline=$true)][string[]]$Hosts)
    begin { $collected = @() }
    process { if ($null -ne $_) { $collected += $_ } }
    end {
        $unique = @($collected | Select-Object -Unique)
        if (-not $unique) { throw 'No host headers selected.' }

        $selectedCN = $null
        while ($true) {
            Clear-Host
            Write-Step 'Step 3: Choose Common Name (CN)'
            Write-Host ''
            if (-not $selectedCN) {
                for ($i = 0; $i -lt $unique.Count; $i++) {
                    $mark = if ($i -eq 0) { '*' } else { ' ' }
                    Write-Host ("$mark  {0,2}: {1}" -f ($i + 1), $unique[$i])
                }
                Write-Host ''
                Write-Host 'Options:' -ForegroundColor Cyan
                Write-Host '  Press Enter     -> Use the default (*) = first host'
                Write-Host '  Type a number   -> Choose from the list above'
                Write-Host '  Type a hostname -> Use any hostname as CN'
                Write-Host '  x               -> Cancel'
                $input = Read-Host 'CN choice'
                switch -Regex ($input) {
                    '^x$'    { throw 'Cancelled by user.' }
                    '^\s*$'  { $selectedCN = $unique[0] }
                    '^\d+$'  {
                        $idx = [int]$input - 1
                        if ($idx -ge 0 -and $idx -lt $unique.Count) { $selectedCN = $unique[$idx] }
                        else { Write-Warn 'Number out of range.'; Pause-UI }
                    }
                    default  { $selectedCN = $input.Trim() }
                }
            } else {
                Write-Host 'You selected the following Common Name (CN):' -ForegroundColor Cyan
                Write-Host "  $selectedCN" -ForegroundColor Yellow
                Write-Host ''
                Write-Host 'Final certificate identifier list (CN first, then sorted):' -ForegroundColor Cyan
                $final = @($selectedCN) + ($unique | Where-Object { $_ -ne $selectedCN } | Sort-Object)
                Write-Host ($final -join ', ')
                Write-Host ''
                Write-Host 'Options:' -ForegroundColor Cyan
                Write-Host '  y -> Confirm and continue'
                Write-Host '  r -> Reselect CN'
                Write-Host '  x -> Cancel'
                $conf = Read-Host 'Confirm? (y/r/x)'
                switch ($conf) {
                    'y' { return [PSCustomObject]@{ CN = $selectedCN; Identifiers = $final } }
                    'r' { $selectedCN = $null }
                    'x' { throw 'Cancelled by user.' }
                    default { Write-Warn 'Invalid choice.'; Pause-UI }
                }
            }
        }
    }
}

# ============================================================
# CERTIFICATE / BINDING UTILITIES
# ============================================================

<#
.SYNOPSIS
    Returns all HTTPS bindings in IIS, with their current certificate thumbprint
    (hex string, no separators) and the corresponding certificate subject if found.
#>
function Get-IISSslBindings {
    $all = Get-IISBindingsRaw | Where-Object { $_.Protocol -ieq 'https' }
    foreach ($b in $all) {
        $subject = ''
        $notAfter = $null
        if ($b.CertificateHash) {
            try {
                $store = [System.Security.Cryptography.X509Certificates.X509Store]::new(
                    $b.CertificateStore, 'LocalMachine')
                $store.Open('ReadOnly')
                $cert = $store.Certificates | Where-Object {
                    $_.Thumbprint -ieq $b.CertificateHash
                } | Select-Object -First 1
                if ($cert) {
                    $subject   = $cert.Subject
                    $notAfter  = $cert.NotAfter
                }
                $store.Close()
            } catch {
                Write-Info "Could not open cert store '$($b.CertificateStore)' for thumbprint $($b.CertificateHash): $_"
            }
        }
        [PSCustomObject]@{
            SiteName        = $b.SiteName
            HostHeader      = $b.HostHeader
            IPAddress       = $b.IPAddress
            Port            = $b.Port
            BindingInfo     = "$($b.IPAddress):$($b.Port):$($b.HostHeader)"
            Thumbprint      = $b.CertificateHash
            CertStore       = $b.CertificateStore
            Subject         = $subject
            NotAfter        = $notAfter
        }
    }
}

function Get-IISBindingsByThumbprint {
    param([string]$Thumbprint)
    if (-not $Thumbprint) { return @() }
    $tp = $Thumbprint.ToLower()
    Get-IISSslBindings | Where-Object { $_.Thumbprint -and $_.Thumbprint.ToLower() -eq $tp }
}

<#
.SYNOPSIS
    Re-binds an existing HTTPS binding to use a different certificate.
    Uses Microsoft.Web.Administration directly so we preserve SslFlags.
#>
function Set-IISBindingCertificate {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$SiteName,
        [Parameter(Mandatory)][string]$BindingInformation,
        [Parameter(Mandatory)][string]$Thumbprint,
        [string]$StoreName = 'WebHosting'
    )
    if (-not $PSCmdlet.ShouldProcess("$SiteName / $BindingInformation", "Re-bind to cert $Thumbprint")) {
        return
    }
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

    $binding.CertificateHash   = $hashBytes
    $binding.CertificateStore  = $StoreName
    $mgr.CommitChanges()
}

# ============================================================
# POSH-ACME COMMAND WRAPPER (handles dry-run / what-if)
# ============================================================

<#
.SYNOPSIS
    Runs (or simulates) a Posh-ACME related action.
    - In Dry-Run: prints $DryRunCommand verbatim, executes nothing.
    - In What-If: calls the scriptblock with -WhatIf attached (best-effort).
    - Otherwise:  calls the scriptblock normally.
#>
function Invoke-PAAction {
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
            Write-Info "Command rejected -WhatIf: $_  -- running in simulated dry-run."
            Write-Host "  $DryRunCommand" -ForegroundColor Gray
        }
        return $null
    }

    & $Action
}

# ============================================================
# POSH-ACME ORDER LISTING
# ============================================================

function Get-PAOrdersList {
    <#
        Returns all Posh-ACME orders across all accounts on the current server.
        Each entry: Name, MainDomain, Identifiers, CertNotAfter, RenewAfter, Thumbprint, Status
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
        try { $cert = $o | Get-PACertificate -ErrorAction SilentlyContinue } catch {}
        $result += [PSCustomObject]@{
            Name        = $o.Name
            MainDomain  = $o.MainDomain
            Identifiers = ($o.Identifiers | ForEach-Object { $_.Value }) -join ','
            Status      = $o.Status
            CertThumb   = if ($cert) { $cert.Thumbprint } else { '' }
            NotAfter    = if ($cert) { $cert.NotAfter } else { $null }
            RenewAfter  = $o.RenewAfter
            Location    = $o.location
        }
    }
    return $result
}

function Get-PACertificateThumbprint {
    param([Parameter(Mandatory)][object]$Order)
    try {
        $cert = $Order | Get-PACertificate -ErrorAction Stop
        return $cert.Thumbprint
    } catch {
        return ''
    }
}

# ============================================================
# ACME ACCOUNT / SERVER SELECTION (S)
# ============================================================

<#
.SYNOPSIS
    Returns the current Posh-ACME server + account (or $null for either if none active).
#>
function Get-CurrentPAContext {
    $srv  = $null
    $acct = $null
    try { $srv  = Get-PAServer  -ErrorAction SilentlyContinue } catch {}
    try { $acct = Get-PAAccount -ErrorAction SilentlyContinue } catch {}
    return [PSCustomObject]@{ Server = $srv; Account = $acct }
}

<#
.SYNOPSIS
    Extracts the bare email from a Posh-ACME contact string ('mailto:foo@bar' -> 'foo@bar').
#>
function Convert-PAContactToEmail {
    param([string]$Contact)
    if (-not $Contact) { return '' }
    if ($Contact -match '^mailto:(.+)$') { return $matches[1] }
    return $Contact
}

<#
.SYNOPSIS
    Returns the value to pass to Set-PAServer for a given Posh-ACME server row.
    Set-PAServer only accepts built-in aliases (LE_PROD, LE_STAGE, etc.) OR a
    full https:// URL — custom short names like 'acme.fragt.root.local' are
    rejected by parameter validation. So for custom servers we use the
    server's 'location' (the actual directory URL).
#>
function ConvertTo-PAServerArg {
    param([Parameter(Mandatory)][object]$Server)
    # Built-in aliases pass validation directly.
    $builtins = @('LE_PROD','LE_STAGE','SSLCOM_RSA','SSLCOM_ECC','ZEROSSL_PROD','GOOGLE_PROD','GOOGLE_STAGE','ACTALIS_PROD')
    if ($Server.Name -and ($Server.Name -in $builtins)) { return $Server.Name }
    # Otherwise use the location URL, which is what Posh-ACME rewrote it to anyway.
    if ($Server.location) { return $Server.location }
    return $Server.Name
}

<#
.SYNOPSIS
    Resolves a user-supplied server identifier (alias, custom short name, or URL)
    to a value that Set-PAServer will accept. If the input is a built-in alias,
    it's returned as-is. If it's already a URL, it's returned as-is. Otherwise
    we look up Get-PAServer -List and return the matching server's location URL.
#>
function Resolve-PAServerArg {
    param([string]$ServerInput)
    if (-not $ServerInput) { return $ServerInput }
    $builtins = @('LE_PROD','LE_STAGE','SSLCOM_RSA','SSLCOM_ECC','ZEROSSL_PROD','GOOGLE_PROD','GOOGLE_STAGE','ACTALIS_PROD')
    if ($ServerInput -in $builtins) { return $ServerInput }
    if ($ServerInput -match '^https?://') { return $ServerInput }
    # Look up by name in the registered server list
    try {
        $srvList = Get-PAServer -List -ErrorAction Stop
        $match = $srvList | Where-Object { $_.Name -eq $ServerInput } | Select-Object -First 1
        if ($match -and $match.location) { return $match.location }
    } catch {}
    # Last resort: return as-is and let Set-PAServer throw a meaningful error
    return $ServerInput
}

<#
.SYNOPSIS
    Enumerates every (server, account) tuple known to Posh-ACME on this machine.
    Uses Posh-ACME's own cmdlets as the source of truth: Get-PAServer -List,
    then for each server Set-PAServer + Get-PAAccount -List. Restores the
    previously active server/account afterwards so the enumeration is read-only.

    NOTE: Set-PAServer only accepts built-in aliases or a full https:// URL,
    so for custom-named servers we pass $srv.location (the directory URL).
#>
function Get-AllPAAccounts {
    # Snapshot the current active context so we can restore it afterwards.
    $origServerArg   = $null
    $origAccountID   = $null
    try {
        $s = Get-PAServer -ErrorAction SilentlyContinue
        if ($s) { $origServerArg = ConvertTo-PAServerArg $s }
    } catch {}
    try {
        $a = Get-PAAccount -ErrorAction SilentlyContinue
        if ($a) { $origAccountID = $a.id }
    } catch {}

    $result = @()
    $srvList = @()
    try { $srvList = Get-PAServer -List -ErrorAction Stop } catch { return $result }

    foreach ($srv in $srvList) {
        $srvArg = ConvertTo-PAServerArg $srv
        try {
            # Switch to this server so Get-PAAccount -List resolves against it.
            # Use the location URL for custom-named servers (Set-PAServer rejects short custom names).
            Set-PAServer $srvArg -ErrorAction Stop | Out-Null
        } catch {
            Write-Info "Could not activate server '$($srv.Name)' (loc=$($srv.location)) for enumeration: $_"
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
            $result += [PSCustomObject]@{
                ServerName = $srv.Name
                ServerLoc  = $srv.location
                ServerArg  = $srvArg
                AccountID  = $a.id
                Contact    = $contact
                Status     = $a.status
                KeyAlg     = $a.alg
                KeyLength  = $a.KeyLength
            }
        }
    }

    # Restore the original active context.
    if ($origServerArg) {
        try { Set-PAServer $origServerArg -ErrorAction SilentlyContinue | Out-Null } catch {}
    }
    if ($origAccountID) {
        try { Set-PAAccount -ID $origAccountID -ErrorAction SilentlyContinue | Out-Null } catch {}
    }

    return $result
}

function Invoke-SelectAccount {
    Show-Banner
    Write-Step 'Select / create ACME account'

    # Show current context
    $ctx = Get-CurrentPAContext
    $curSrv  = if ($ctx.Server) { $ctx.Server.Name } else { '(none)' }
    $curAcct = if ($ctx.Account) { $ctx.Account.id } else { '(none)' }
    $curMail = if ($ctx.Account -and $ctx.Account.contact) {
        ($ctx.Account.contact | ForEach-Object { Convert-PAContactToEmail $_ }) -join ';'
    } else { '' }
    Write-Host 'Current context:' -ForegroundColor Cyan
    Write-Host "  Server  : $curSrv"
    Write-Host "  Account : $curAcct  $(if ($curMail) { "($curMail)" })"
    Write-Host ''

    $accounts = Get-AllPAAccounts
    if (-not $accounts) {
        Write-Warn 'No Posh-ACME accounts found on this machine.'
        Write-Host '  Press n to create one, or c to cancel.' -ForegroundColor Cyan
    } else {
        Write-Host 'Available accounts:' -ForegroundColor Cyan
        $i = 0
        $accounts | ForEach-Object {
            $i++
            $mail = if ($_.Contact) { $_.Contact } else { '(no contact)' }
            $idShort = if ($_.AccountID -and $_.AccountID.Length -gt 20) { $_.AccountID.Substring(0,20) + '...' } else { $_.AccountID }
            $active  = if ($ctx.Server -and $ctx.Account -and
                           $ctx.Server.Name -eq $_.ServerName -and
                           $ctx.Account.id -eq $_.AccountID) { ' *' } else { '  ' }
            Write-Host ("$active{0,2}: [{1,-24}] {2,-22} {3}  ({4})  {5}/{6}" -f `
                $i, $_.ServerName, $idShort, $_.Status, $mail, $_.KeyAlg, $_.KeyLength)
        }
        Write-Host ''
        Write-Host '  * = currently active' -ForegroundColor DarkGray
    }

    Write-Host ''
    Write-Host 'Options:' -ForegroundColor Cyan
    Write-Host '  <number>   Select that account (also activates its server)'
    Write-Host '  n          Create a new account on a chosen server'
    Write-Host '  c          Cancel'
    Write-Host ''
    $line = Read-Host 'Choice'
    if (-not $line) { return }
    $key = $line.Trim().ToLower()
    if ($key -eq 'c') { return }

    if ($key -eq 'n') {
        Invoke-CreateNewAccount
        return
    }

    if ($key -match '^\d+$') {
        $idx = [int]$key - 1
        if (-not $accounts -or $idx -lt 0 -or $idx -ge $accounts.Count) {
            Write-Warn 'Number out of range.'
            Pause-UI
            return
        }
        $sel = $accounts[$idx]
        # Use ServerArg (URL for custom servers, alias for built-in) so Set-PAServer validation passes.
        $srvArg = if ($sel.ServerArg) { $sel.ServerArg } else { $sel.ServerName }
        Write-Host ''
        Write-Host "Selecting: [$($sel.ServerName)] $($sel.AccountID)  ($($sel.Contact))" -ForegroundColor Cyan
        Write-Host "  (activating via: $srvArg)" -ForegroundColor DarkGray

        $dryCmd = "Set-PAServer '$srvArg'; Set-PAAccount -ID '$($sel.AccountID)'"
        Invoke-PAAction -Description "Activate server '$($sel.ServerName)'" `
            -DryRunCommand "Set-PAServer '$srvArg'" `
            -Action { Set-PAServer $srvArg }

        Invoke-PAAction -Description "Activate account '$($sel.AccountID)'" `
            -DryRunCommand "Set-PAAccount -ID '$($sel.AccountID)'" `
            -Action { Set-PAAccount -ID $sel.AccountID }

        if ($script:DryRun) {
            Write-Host ''
            Write-Warn 'DRY-RUN: no context change applied.'
            Write-Host "  $dryCmd" -ForegroundColor Gray
        } else {
            # Reflect the chosen server in the persisted config so subsequent N/R/A flows use it.
            # Store the human-readable Name; ConvertTo-PAServerArg is used wherever Set-PAServer is called.
            $script:Config.ACMEServer = $sel.ServerName
            Save-Config
            Write-Ok "Active: server=$($sel.ServerName)  account=$($sel.AccountID)"
        }
        Pause-UI
        return
    }

    Write-Warn 'Unknown choice.'
    Pause-UI
}

function Invoke-CreateNewAccount {
    Write-Host ''
    Write-Step 'Create a new ACME account'

    # ---- Pick a server ----
    $srvList = @()
    try { $srvList = Get-PAServer -List -ErrorAction Stop } catch {}
    if (-not $srvList) {
        Write-Warn 'No ACME servers are configured yet.'
        Write-Host '  Built-in aliases you can use: LE_PROD, LE_STAGE'
        Write-Host '  Or enter a full directory URL.'
    } else {
        Write-Host 'Known servers:' -ForegroundColor Cyan
        $i = 0
        $srvList | ForEach-Object {
            $i++
            Write-Host ("  {0,2}: {1}  ({2})" -f $i, $_.Name, $_.location)
        }
    }
    Write-Host ''
    Write-Host 'Options:' -ForegroundColor Cyan
    Write-Host '  <number>   Use that existing server'
    Write-Host '  p          Use LE_PROD (Let''s Encrypt production)'
    Write-Host '  t          Use LE_STAGE (Let''s Encrypt staging)'
    Write-Host '  u <url>    Add a new server from this directory URL'
    Write-Host '  c          Cancel'
    $srvLine = Read-Host 'Server'
    if (-not $srvLine) { return }
    $parts = $srvLine -split '\s+', 2
    $sCmd  = $parts[0].ToLower()
    $sArg  = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }

    $srvName = ''
    switch ($sCmd) {
        'c' { return }
        'p' { $srvName = 'LE_PROD' }
        't' { $srvName = 'LE_STAGE' }
        'u' {
            if (-not $sArg) { Write-Warn 'Provide a directory URL.'; Pause-UI; return }
            $srvName = $sArg
        }
        default {
            if ($sCmd -match '^\d+$' -and $srvList) {
                $idx = [int]$sCmd - 1
                if ($idx -ge 0 -and $idx -lt $srvList.Count) { $srvName = $srvList[$idx].Name }
                else { Write-Warn 'Number out of range.'; Pause-UI; return }
            } else {
                Write-Warn "Unknown input '$srvLine'."; Pause-UI; return
            }
        }
    }

    # ---- Ask for contact email ----
    Write-Host ''
    Write-Host "Server: $srvName" -ForegroundColor Cyan
    $email = Read-Host 'Contact email (e.g. admin@contoso.com)'
    if (-not $email -or $email -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
        Write-Warn 'Invalid email. Aborting.'
        Pause-UI
        return
    }

    # Resolve to Set-PAServer-compatible argument (URL for custom names, alias for built-ins)
    $srvArg = Resolve-PAServerArg $srvName
    $dryCmdSet  = "Set-PAServer $srvArg"
    $dryCmdNew  = "New-PAAccount -Contact '$email' -AcceptTos"

    if (-not (Confirm-Prompt "Create account on '$srvName'$(if ($srvArg -ne $srvName) { " (via $srvArg)" }) with contact '$email'?")) { return }

    Invoke-PAAction -Description "Set ACME server to '$srvName'" `
        -DryRunCommand $dryCmdSet `
        -Action { Set-PAServer $srvArg }

    Invoke-PAAction -Description 'Create new ACME account' `
        -DryRunCommand $dryCmdNew `
        -Action { New-PAAccount -Contact $email -AcceptTos }

    if ($script:DryRun) {
        Write-Host ''
        Write-Warn 'DRY-RUN: no account was created.'
        Write-Host "  $dryCmdSet; $dryCmdNew" -ForegroundColor Gray
    } else {
        $script:Config.ACMEServer   = $srvName
        $script:Config.ContactEmail = $email
        Save-Config
        $newAcct = $null
        try { $newAcct = Get-PAAccount -ErrorAction SilentlyContinue } catch {}
        if ($newAcct) {
            Write-Ok "Account created. id=$($newAcct.id)  contact=$email  server=$srvName"
        } else {
            Write-Ok 'Account creation submitted. Verify output above.'
        }
    }
    Pause-UI
}

# ============================================================
# MENU ACTION: CREATE CERTIFICATE (N)
# ============================================================

function Invoke-CreateCertificate {
    Show-Banner
    Write-Step 'Create certificate (full options)'

    try {
        $result = Select-IISSitesUI | Select-IISBindingsUI | Select-IISCommonNameUI
    } catch {
        Write-Warn $_.Exception.Message
        Pause-UI
        return
    }

    $cn          = $result.CN
    $identifiers = $result.Identifiers

    Clear-Host
    Write-Step 'Step 4: ACME options'
    Write-Host "CN            : $cn"
    Write-Host "Identifiers   : $($identifiers -join ', ')"
    Write-Host ''
    Write-Host 'Current settings:'
    Write-Host "  ACME Server       : $($script:Config.ACMEServer)"
    Write-Host "  Contact Email     : $($script:Config.ContactEmail)"
    Write-Host "  Key Type / Length : $($script:Config.KeyType) $($script:Config.KeyLength)"
    Write-Host "  Validation Plugin : $($script:Config.ValidationPlugin)"
    Write-Host "  Cert Store        : $($script:Config.CertStore)"
    Write-Host ''
    Write-Host 'Options:' -ForegroundColor Cyan
    Write-Host '  e <email>    Set contact email'
    Write-Host '  s <server>   Set ACME server (LE_PROD | LE_STAGE | <url>)'
    Write-Host '  k <type>     Key type (RSA or EC)'
    Write-Host '  l <length>   Key length (RSA: 2048/3072/4096, EC: 256/384)'
    Write-Host '  v <plugin>   Validation plugin (WebSelfHost | <DNS plugin>)'
    Write-Host '  c            Confirm and request certificate'
    Write-Host '  x            Cancel'

    while ($true) {
        $line = Read-Host 'Command'
        if (-not $line) { continue }
        $parts = $line -split '\s+', 2
        $cmd   = $parts[0].ToLower()
        $arg   = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }
        switch ($cmd) {
            'e' { if ($arg) { $script:Config.ContactEmail = $arg; Save-Config } }
            's' { if ($arg) { $script:Config.ACMEServer = $arg; Save-Config } }
            'k' { if ($arg -in 'RSA','EC') { $script:Config.KeyType = $arg; Save-Config } }
            'l' { if ($arg -match '^\d+$') { $script:Config.KeyLength = [int]$arg; Save-Config } }
            'v' { if ($arg) { $script:Config.ValidationPlugin = $arg; Save-Config } }
            'c' { break }
            'x' { return }
            default { Write-Warn 'Unknown command.'; continue }
        }
        if ($cmd -eq 'c') { break }
        # re-display header for next iteration
        Clear-Host
        Write-Step 'Step 4: ACME options'
        Write-Host "CN            : $cn"
        Write-Host "Identifiers   : $($identifiers -join ', ')"
        Write-Host ''
        Write-Host 'Current settings:'
        Write-Host "  ACME Server       : $($script:Config.ACMEServer)"
        Write-Host "  Contact Email     : $($script:Config.ContactEmail)"
        Write-Host "  Key Type / Length : $($script:Config.KeyType) $($script:Config.KeyLength)"
        Write-Host "  Validation Plugin : $($script:Config.ValidationPlugin)"
        Write-Host "  Cert Store        : $($script:Config.CertStore)"
        Write-Host ''
        Write-Host 'Options:' -ForegroundColor Cyan
        Write-Host '  e <email>    Set contact email'
        Write-Host '  s <server>   Set ACME server (LE_PROD | LE_STAGE | <url>)'
        Write-Host '  k <type>     Key type (RSA or EC)'
        Write-Host '  l <length>   Key length (RSA: 2048/3072/4096, EC: 256/384)'
        Write-Host '  v <plugin>   Validation plugin (WebSelfHost | <DNS plugin>)'
        Write-Host '  c            Confirm and request certificate'
        Write-Host '  x            Cancel'
    }

    # ---- Build & confirm final command ----
    $domains = $identifiers -join ','
    $email   = $script:Config.ContactEmail
    $server  = $script:Config.ACMEServer
    $kType   = $script:Config.KeyType
    $kLen    = $script:Config.KeyLength
    $plugin  = $script:Config.ValidationPlugin
    $store   = $script:Config.CertStore

    if (-not $email) {
        Write-Err 'Contact email is required. Use ''e <email>'' in the previous step.'
        Pause-UI
        return
    }

    # Resolve the configured server name to a Set-PAServer-compatible argument.
    # (Built-in aliases pass through; custom short names like 'acme.fragt.root.local'
    # are converted to their https:// location URL.)
    $serverArg = Resolve-PAServerArg $server

    $cmdLine = "Set-PAServer $serverArg; New-PAAccount -Contact '$email' -AcceptTos -Quiet; " +
               "New-PACertificate -Domain '$domains' -DnsPlugin $plugin -Install" +
               " -KeyType $kType -KeyLength $kLen -CertStore $store"

    Clear-Host
    Write-Step 'Step 5: Confirm & run'
    Write-Host 'About to request a certificate with the following parameters:' -ForegroundColor Cyan
    Write-Host "  Domains          : $domains"
    Write-Host "  CN               : $cn"
    Write-Host "  ACME Server      : $server  $(if ($serverArg -ne $server) { "($serverArg)" })"
    Write-Host "  Contact Email    : $email"
    Write-Host "  Key              : $kType $kLen"
    Write-Host "  Validation       : $plugin"
    Write-Host "  Cert Store       : $store"
    Write-Host ''
    Write-Host 'Equivalent PowerShell command:' -ForegroundColor DarkCyan
    Write-Host "  $cmdLine" -ForegroundColor Gray
    Write-Host ''
    if (-not (Confirm-Prompt 'Proceed?')) { Write-Warn 'Cancelled.'; Pause-UI; return }

    # ---- Execute (or simulate) ----
    Invoke-PAAction -Description 'Set ACME server' `
        -DryRunCommand "Set-PAServer $serverArg" `
        -Action { Set-PAServer $serverArg }

    # ---- Reuse active account if one exists on this server; create otherwise ----
    $activeAcct = $null
    if (-not $script:DryRun) {
        try { $activeAcct = Get-PAAccount -List -Refresh -ErrorAction Stop |
                Where-Object { $_.status -eq 'valid' } |
                Select-Object -First 1 } catch {}
    }
    if ($activeAcct) {
        $mail = if ($activeAcct.contact) {
            ($activeAcct.contact | ForEach-Object { Convert-PAContactToEmail $_ }) -join ';'
        } else { '(no contact)' }
        Write-Info "Reusing active account: $($activeAcct.id)  ($mail)"
        Invoke-PAAction -Description "Activate account $($activeAcct.id)" `
            -DryRunCommand "Set-PAAccount -ID '$($activeAcct.id)'" `
            -Action { Set-PAAccount -ID $activeAcct.id }
    } else {
        if ($script:DryRun) {
            Write-Warn 'DRY-RUN: no account lookup performed. In a real run, an existing valid account'
            Write-Warn '         on this server would be reused. Otherwise a new account is created.'
        }
        Invoke-PAAction -Description 'Create new ACME account' `
            -DryRunCommand "New-PAAccount -Contact '$email' -AcceptTos -Quiet" `
            -Action { New-PAAccount -Contact $email -AcceptTos -Quiet }
    }

    $newCert = Invoke-PAAction -Description 'Request & install certificate' `
        -DryRunCommand $cmdLine `
        -Action {
            New-PACertificate -Domain $identifiers -DnsPlugin $plugin -Install `
                -KeyType $kType -KeyLength $kLen -CertStore $store
        }

    if ($script:DryRun) {
        Write-Host ''
        Write-Warn 'DRY-RUN: No certificate was generated. Review the command above.'
        Write-Host ''
        Write-Host 'Bindings that would be re-pointed to the new certificate (one per identifier):' -ForegroundColor Cyan
        foreach ($h in $identifiers) {
            $matching = Get-IISSslBindings | Where-Object { $_.HostHeader -ieq $h }
            if ($matching) {
                $matching | ForEach-Object {
                    Write-Host ("    -> {0} / {1}" -f $_.SiteName, $_.BindingInfo) -ForegroundColor Gray
                }
            } else {
                Write-Host "    (no HTTPS binding for $h)" -ForegroundColor DarkGray
            }
        }
        Pause-UI
        return
    }

    if (-not $newCert -or -not $newCert.Thumbprint) {
        Write-Warn 'Certificate object was not returned. Verify Posh-ACME output above.'
        Pause-UI
        return
    }

    $newTP = $newCert.Thumbprint
    Write-Ok "Certificate issued. Thumbprint: $newTP"

    # ---- Re-point matching HTTPS bindings to the new certificate ----
    Write-Host ''
    Write-Step 'Step 6: Bind IIS HTTPS bindings to the new certificate'
    $toBind = @()
    foreach ($h in $identifiers) {
        $toBind += @(Get-IISSslBindings | Where-Object { $_.HostHeader -ieq $h })
    }
    if (-not $toBind) {
        Write-Info 'No existing HTTPS bindings match the requested identifiers. Nothing to bind.'
        Pause-UI
        return
    }
    Write-Host 'Bindings to update:' -ForegroundColor Cyan
    $toBind | ForEach-Object {
        Write-Host ("  {0} / {1}  (current thumb: {2})" -f $_.SiteName, $_.BindingInfo, $_.Thumbprint)
    }
    if (-not (Confirm-Prompt "Rebind $($toBind.Count) binding(s) to new cert?")) {
        Write-Warn 'Skipped IIS rebind. Certificate installed in store but not bound.'
        Pause-UI
        return
    }
    $ok = 0; $fail = 0
    foreach ($b in $toBind) {
        try {
            Set-IISBindingCertificate -SiteName $b.SiteName -BindingInformation $b.BindingInformation `
                -Thumbprint $newTP -StoreName $script:Config.CertStore
            Write-Ok "$($b.SiteName) / $($b.BindingInformation)"
            $ok++
        } catch {
            Write-Err "Failed: $($b.SiteName) / $($b.BindingInformation): $_"
            $fail++
        }
    }
    Write-Host ''
    Write-Ok "Bind complete. Success: $ok  Failed: $fail"
    Pause-UI
}

# ============================================================
# MENU ACTION: RENEW SINGLE CERTIFICATE (R)
# ============================================================

function Invoke-RenewSingle {
    Show-Banner
    Write-Step 'Renew a single certificate'

    $orders = Get-PAOrdersList
    if (-not $orders) {
        Write-Warn 'No Posh-ACME orders found on this server.'
        Pause-UI
        return
    }

    Write-Host 'Existing orders:' -ForegroundColor Cyan
    $i = 0
    $orders | ForEach-Object {
        $i++
        $exp = if ($_.NotAfter) { $_.NotAfter.ToString('yyyy-MM-dd') } else { '-' }
        Write-Host ("  {0,2}: {1}  | expires: {2}  | SAN: {3}" -f $i, $_.MainDomain, $exp, $_.Identifiers)
    }
    Write-Host ''
    Write-Host '  0: Cancel'
    Write-Host ''
    $sel = Read-Host 'Pick an order (number)'
    if ($sel -eq '0' -or -not $sel) { return }
    if ($sel -notmatch '^\d+$') { Write-Warn 'Invalid number.'; Pause-UI; return }
    $idx = [int]$sel - 1
    if ($idx -lt 0 -or $idx -ge $orders.Count) { Write-Warn 'Out of range.'; Pause-UI; return }

    $order  = $orders[$idx]
    $oldTP  = $order.CertThumb
    Write-Host ''
    Write-Host "Renewing: $($order.MainDomain)  (current thumb: $oldTP)" -ForegroundColor Cyan

    $cmdLine = "Get-PAOrder -Name '$($order.Name)' | Out-Null; Submit-Renewal -Force"

    if (-not (Confirm-Prompt "Renew '$($order.MainDomain)'?")) { return }

    # Set the chosen order as the current PAOrder context (required by Submit-Renewal)
    Invoke-PAAction -Description "Select order '$($order.Name)' as current" `
        -DryRunCommand "Get-PAOrder -Name '$($order.Name)' | Out-Null" `
        -Action { Get-PAOrder -Name $order.Name | Out-Null }

    Invoke-PAAction -Description "Submit renewal for $($order.MainDomain)" `
        -DryRunCommand $cmdLine `
        -Action { Submit-Renewal -Force }

    if ($script:DryRun) {
        Write-Host ''
        Write-Warn 'DRY-RUN: After a real renewal, all IIS bindings using the old thumbprint would be re-bound:'
        if ($oldTP) {
            Get-IISBindingsByThumbprint -Thumbprint $oldTP | ForEach-Object {
                Write-Host "    -> $($_.SiteName) / $($_.BindingInfo)" -ForegroundColor Gray
            }
        } else {
            Write-Host '    (no previous thumbprint recorded)'
        }
        Write-Host ''
        Write-Host 'To automate this renewal via Windows Task Scheduler, register a task that runs:'
        Write-Host '  PoshAcme-Renew.ps1 -ServerName <srv> -AccountID <id>'
        Write-Host ''
        Write-Host 'Equivalent pwsh.exe action (use in Task Scheduler "Start a program"):'
        $cmds = Get-RenewalScheduledTaskCommand -TaskName "$($script:TaskPrefix)Renew-$($order.MainDomain)" `
            -ServerName $script:Config.ACMEServer -AccountID ($order.Name)
        Write-Host "  $($cmds.ActionCmd)" -ForegroundColor Gray
        Write-Host ''
        Write-Host 'Equivalent schtasks.exe one-liner (run from elevated cmd):'
        Write-Host "  $($cmds.SchtasksCmd)" -ForegroundColor Gray
        Pause-UI
        return
    }

    # ---- Re-bind all HTTPS bindings using the old cert thumbprint ----
    $renewed = Get-PAOrder -Name $order.Name
    $newCert = $renewed | Get-PACertificate -ErrorAction SilentlyContinue
    if (-not $newCert) {
        Write-Err 'Renewal completed but new certificate object could not be loaded. Manual re-bind required.'
        Pause-UI
        return
    }
    $newTP = $newCert.Thumbprint
    Write-Ok "New certificate thumbprint: $newTP"

    if (-not $oldTP) {
        Write-Warn 'No old thumbprint recorded; cannot auto-rebind IIS bindings.'
        Pause-UI
        return
    }

    $bindingsToRebind = Get-IISBindingsByThumbprint -Thumbprint $oldTP
    if (-not $bindingsToRebind) {
        Write-Info 'No IIS bindings were using the old certificate; nothing to rebind.'
        Pause-UI
        return
    }

    Write-Host ''
    Write-Host 'Bindings to update:' -ForegroundColor Cyan
    $bindingsToRebind | ForEach-Object {
        Write-Host ("  {0} / {1}  (was: {2})" -f $_.SiteName, $_.BindingInfo, $oldTP)
    }
    if (-not (Confirm-Prompt "Rebind $($bindingsToRebind.Count) binding(s) to new cert?")) {
        Write-Warn 'Skipped IIS rebind. Old certificate remains in place.'
        Pause-UI
        return
    }

    $ok = 0; $fail = 0
    foreach ($b in $bindingsToRebind) {
        try {
            Invoke-PAAction -Description "Rebind $($b.SiteName) / $($b.BindingInfo)" `
                -DryRunCommand "Set-IISBindingCertificate -SiteName '$($b.SiteName)' -BindingInformation '$($b.BindingInfo)' -Thumbprint '$newTP' -StoreName '$($script:Config.CertStore)'" `
                -Action { Set-IISBindingCertificate -SiteName $b.SiteName -BindingInformation $b.BindingInformation -Thumbprint $newTP -StoreName $script:Config.CertStore }
            $ok++
        } catch {
            Write-Err "Failed to rebind $($b.SiteName) / $($b.BindingInformation): $_"
            $fail++
        }
    }
    Write-Host ''
    Write-Ok "Rebind complete. Success: $ok  Failed: $fail"
    Pause-UI
}

# ============================================================
# MENU ACTION: RUN ALL RENEWALS (A)
# ============================================================

function Invoke-RenewAll {
    Show-Banner
    Write-Step 'Run all renewals (batch)'

    $orders = Get-PAOrdersList
    if (-not $orders) {
        Write-Warn 'No Posh-ACME orders found on this server.'
        Pause-UI
        return
    }

    Write-Host 'Orders that will be considered for renewal:' -ForegroundColor Cyan
    $orders | ForEach-Object {
        $exp = if ($_.NotAfter) { $_.NotAfter.ToString('yyyy-MM-dd') } else { '-' }
        $renew = if ($_.RenewAfter -and $_.RenewAfter -le (Get-Date)) { 'DUE' } else { 'not due' }
        Write-Host ("  {0,-40} expires {1}  ({2})" -f $_.MainDomain, $exp, $renew)
    }
    Write-Host ''
    if (-not (Confirm-Prompt 'Submit renewal for all due orders?')) { return }

    # Snapshot the OLD thumbprint per order BEFORE renewal, so we can rebind afterwards.
    $thumbprintBefore = @{}
    foreach ($o in $orders) {
        if ($o.CertThumb) { $thumbprintBefore[$o.Name] = $o.CertThumb }
    }

    $cmdLine = 'Submit-Renewal -RenewAll'
    Invoke-PAAction -Description 'Submit renewal for all due orders' `
        -DryRunCommand $cmdLine `
        -Action { Submit-Renewal -RenewAll }

    if ($script:DryRun) {
        Write-Host ''
        Write-Warn 'DRY-RUN: In a real run, every due order would be renewed, then every IIS HTTPS binding using each old thumbprint would be re-bound to the corresponding new thumbprint.'
        Write-Host 'Bindings that would be considered for re-bind (per order):' -ForegroundColor Cyan
        foreach ($k in $thumbprintBefore.Keys) {
            $old = $thumbprintBefore[$k]
            $list = Get-IISBindingsByThumbprint -Thumbprint $old
            if ($list) {
                Write-Host "  Order '$k' (old thumb $old):" -ForegroundColor Yellow
                $list | ForEach-Object { Write-Host ("    -> {0} / {1}" -f $_.SiteName, $_.BindingInfo) -ForegroundColor Gray }
            }
        }
        Write-Host ''
        Write-Host 'To automate this batch renewal via Windows Task Scheduler, use T: Manage scheduled'
        Write-Host 'renewal tasks, or register one manually with the commands below.'
        Write-Host ''
        Write-Host 'Equivalent pwsh.exe action (use in Task Scheduler "Start a program"):'
        $cmds = Get-RenewalScheduledTaskCommand -TaskName "$($script:TaskPrefix)RenewAll" `
            -ServerName $script:Config.ACMEServer
        Write-Host "  $($cmds.ActionCmd)" -ForegroundColor Gray
        Write-Host ''
        Write-Host 'Equivalent schtasks.exe one-liner (run from elevated cmd):'
        Write-Host "  $($cmds.SchtasksCmd)" -ForegroundColor Gray
        Pause-UI
        return
    }

    # ---- Re-bind all bindings using pre-renewal thumbprints ----
    Write-Host ''
    Write-Step 'Re-binding IIS bindings to renewed certificates'
    $renewedOrders = Get-PAOrdersList
    $ok = 0; $fail = 0
    foreach ($ro in $renewedOrders) {
        if (-not $thumbprintBefore.ContainsKey($ro.Name)) { continue }
        $oldTP = $thumbprintBefore[$ro.Name]
        $newCert = $null
        try { $newCert = (Get-PAOrder -Name $ro.Name) | Get-PACertificate -ErrorAction Stop } catch {}
        if (-not $newCert -or -not $newCert.Thumbprint) { continue }
        $newTP = $newCert.Thumbprint
        if ($newTP -ieq $oldTP) {
            Write-Info "$($ro.MainDomain): thumbprint unchanged ($newTP), skipping rebind."
            continue
        }
        $bindings = Get-IISBindingsByThumbprint -Thumbprint $oldTP
        foreach ($b in $bindings) {
            try {
                Set-IISBindingCertificate -SiteName $b.SiteName -BindingInformation $b.BindingInformation `
                    -Thumbprint $newTP -StoreName $script:Config.CertStore
                Write-Ok "$($b.SiteName) / $($b.BindingInformation) -> $newTP"
                $ok++
            } catch {
                Write-Err "Failed: $($b.SiteName) / $($b.BindingInformation): $_"
                $fail++
            }
        }
    }
    Write-Host ''
    Write-Ok "Batch rebind complete. Success: $ok  Failed: $fail"
    Pause-UI
}

# ============================================================
# MENU ACTION: MANAGE RENEWALS (M)
# ============================================================

function Invoke-ManageRenewals {
    Show-Banner
    Write-Step 'Manage renewals'

    $orders = Get-PAOrdersList
    if (-not $orders) {
        Write-Warn 'No Posh-ACME orders found on this server.'
        Pause-UI
        return
    }

    $i = 0
    $orders | ForEach-Object {
        $i++
        $exp = if ($_.NotAfter) { $_.NotAfter.ToString('yyyy-MM-dd') } else { '-' }
        Write-Host ("  {0,2}: {1}  | expires: {2}  | SAN: {3}" -f $i, $_.MainDomain, $exp, $_.Identifiers)
    }
    Write-Host ''
    Write-Host 'Options:' -ForegroundColor Cyan
    Write-Host '  v <n>   View details of order #n'
    Write-Host '  r <n>   Force-renew order #n'
    Write-Host '  d <n>   Delete order #n (does NOT revoke cert)'
    Write-Host '  c       Cancel'
    Write-Host ''

    $line = Read-Host 'Command'
    if (-not $line) { return }
    $parts = $line -split '\s+', 2
    $cmd   = $parts[0].ToLower()
    $arg   = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }

    if ($cmd -eq 'c') { return }
    if (-not $arg -or $arg -notmatch '^\d+$') { Write-Warn 'Provide a number.'; Pause-UI; return }
    $idx = [int]$arg - 1
    if ($idx -lt 0 -or $idx -ge $orders.Count) { Write-Warn 'Out of range.'; Pause-UI; return }
    $order = $orders[$idx]

    switch ($cmd) {
        'v' {
            Clear-Host
            Write-Step "Order detail: $($order.MainDomain)"
            Write-Host "Name        : $($order.Name)"
            Write-Host "MainDomain  : $($order.MainDomain)"
            Write-Host "Identifiers : $($order.Identifiers)"
            Write-Host "Status      : $($order.Status)"
            Write-Host "Thumbprint  : $($order.CertThumb)"
            Write-Host "NotAfter    : $(if ($order.NotAfter) { $order.NotAfter.ToString('yyyy-MM-dd HH:mm') } else { '-' })"
            Write-Host "RenewAfter  : $(if ($order.RenewAfter) { $order.RenewAfter.ToString('yyyy-MM-dd HH:mm') } else { '-' })"
            Write-Host "Location    : $($order.Location)"
            Write-Host ''
            $bound = if ($order.CertThumb) { Get-IISBindingsByThumbprint -Thumbprint $order.CertThumb } else { @() }
            if ($bound) {
                Write-Host 'IIS bindings currently using this certificate:' -ForegroundColor Cyan
                $bound | ForEach-Object {
                    Write-Host ("  {0} / {1}" -f $_.SiteName, $_.BindingInfo)
                }
            } else {
                Write-Host 'IIS bindings currently using this certificate: NONE' -ForegroundColor DarkGray
            }
            Pause-UI
        }
        'r' {
            if (-not (Confirm-Prompt "Force-renew '$($order.MainDomain)'?")) { return }
            # Set the chosen order as current context first
            Invoke-PAAction -Description "Select order '$($order.Name)' as current" `
                -DryRunCommand "Get-PAOrder -Name '$($order.Name)' | Out-Null" `
                -Action { Get-PAOrder -Name $order.Name | Out-Null }
            Invoke-PAAction -Description "Force-renew $($order.MainDomain)" `
                -DryRunCommand "Submit-Renewal -Force" `
                -Action { Submit-Renewal -Force }
            Pause-UI
        }
        'd' {
            if (-not (Confirm-Prompt "Delete order '$($order.MainDomain)'? (Certificate will NOT be revoked.)")) { return }
            Invoke-PAAction -Description "Delete order $($order.MainDomain)" `
                -DryRunCommand "Remove-PAOrder -Name '$($order.Name)' -Force" `
                -Action { Remove-PAOrder -Name $order.Name -Force -ErrorAction SilentlyContinue }
            Pause-UI
        }
        default { Write-Warn 'Unknown command.'; Pause-UI }
    }
}

# ============================================================
# MENU ACTION: BROWSE IIS BINDINGS (B)
# ============================================================

function Invoke-BrowseIISBindings {
    Show-Banner
    Write-Step 'Browse IIS bindings'

    $bindings = Get-IISSslBindings
    if (-not $bindings) {
        Write-Warn 'No HTTPS bindings found in IIS.'
        Pause-UI
        return
    }

    $table = $bindings | Select-Object `
        @{N='Site';      E={$_.SiteName}},
        @{N='Host';      E={$_.HostHeader}},
        @{N='IP:Port';   E={"$($_.IPAddress):$($_.Port)"}},
        @{N='Thumbprint';E={$_.Thumbprint}},
        @{N='Subject';   E={$_.Subject}},
        @{N='Expires';   E={if ($_.NotAfter) { $_.NotAfter.ToString('yyyy-MM-dd') } else { '-' }}} `
        | Format-Table -AutoSize | Out-String
    Write-Host $table

    Write-Host ''
    Write-Host 'Filters:' -ForegroundColor Cyan
    Write-Host '  t <thumbprint>   Show only bindings using this cert thumbprint'
    Write-Host '  s <site>         Show only bindings on this site'
    Write-Host '  e                Show only expired (<30 days) certificates'
    Write-Host '  c                Clear filter'
    Write-Host '  x                Back to main menu'

    while ($true) {
        $line = Read-Host 'Filter (or x)'
        if (-not $line) { continue }
        $parts = $line -split '\s+', 2
        $cmd   = $parts[0].ToLower()
        $arg   = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }
        switch ($cmd) {
            'x' { return }
            't' {
                if (-not $arg) { Write-Warn 'Provide a thumbprint.'; continue }
                Clear-Host
                Write-Step "Bindings using thumbprint: $arg"
                $filtered = $bindings | Where-Object { $_.Thumbprint -ieq $arg }
                if (-not $filtered) { Write-Warn 'No matches.'; Pause-UI; return }
                $filtered | Format-Table -AutoSize
                Pause-UI
                return
            }
            's' {
                if (-not $arg) { Write-Warn 'Provide a site name.'; continue }
                Clear-Host
                Write-Step "Bindings on site: $arg"
                $filtered = $bindings | Where-Object { $_.SiteName -ieq $arg }
                if (-not $filtered) { Write-Warn 'No matches.'; Pause-UI; return }
                $filtered | Format-Table -AutoSize
                Pause-UI
                return
            }
            'e' {
                Clear-Host
                Write-Step 'Bindings using certificates expiring within 30 days'
                $cutoff = (Get-Date).AddDays(30)
                $filtered = $bindings | Where-Object { $_.NotAfter -and $_.NotAfter -le $cutoff }
                if (-not $filtered) { Write-Ok 'No certificates expiring within 30 days.'; Pause-UI; return }
                $filtered | Format-Table -AutoSize
                Pause-UI
                return
            }
            'c' { return }
            default { Write-Warn 'Unknown command.' }
        }
    }
}

# ============================================================
# SCHEDULED TASK MANAGEMENT (T)
# ============================================================

# Default path where PoshAcme-Renew.ps1 is expected to live. The script auto-detects
# its own directory at runtime, but the user can override in the create flow.
$script:TaskPrefix = 'PoshTUI-'

function Get-ScriptInstallDir {
    <#
        Returns the directory this script is running from. PoshAcme-Renew.ps1
        is expected to live in the same directory.
    #>
    if ($MyInvocation.ScriptName) { return Split-Path $MyInvocation.ScriptName -Parent }
    # Fallback: $PSScriptRoot works in pwsh 3+
    return $PSScriptRoot
}

function Get-RenewalTaskPrefixFilter {
    return "$script:TaskPrefix*"
}

function Get-PoshTUIRenewalTasks {
    <#
        Lists all scheduled tasks whose name starts with 'PoshTUI-'.
        Returns PSCustomObjects with: TaskName, State, NextRunTime, LastRunTime, LastTaskResult
    #>
    $result = @()
    try {
        $tasks = Get-ScheduledTask -TaskName (Get-RenewalTaskPrefixFilter) -ErrorAction Stop
    } catch {
        # Tasks not found — not necessarily an error
        return $result
    }
    foreach ($t in $tasks) {
        $info = $t | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue
        $action = $t.Actions | Select-Object -First 1
        $trigger = $t.Triggers | Select-Object -First 1
        $result += [PSCustomObject]@{
            TaskName        = $t.TaskName
            State           = $t.State
            NextRunTime     = if ($info -and $info.NextRunTime -and $info.NextRunTime -ne (Get-Date '0001-01-01')) { $info.NextRunTime } else { $null }
            LastRunTime     = if ($info -and $info.LastRunTime -and $info.LastRunTime -ne (Get-Date '0001-01-01')) { $info.LastRunTime } else { $null }
            LastTaskResult  = if ($info) { $info.LastTaskResult } else { 0 }
            Execute         = if ($action) { $action.Execute } else { '' }
            Arguments       = if ($action) { $action.Arguments } else { '' }
            TriggerType     = if ($trigger) { $trigger.CimClass.CimClassName } else { '' }
            StartTime       = if ($trigger -and $trigger.StartBoundary) { $trigger.StartBoundary } else { '' }
            DaysOfWeek      = if ($trigger -and $trigger.DaysOfWeek) { $trigger.DaysOfWeek } else { $null }
        }
    }
    return $result
}

function Get-RenewalScriptPath {
    <# Returns the expected path to PoshAcme-Renew.ps1 in the same dir as this script. #>
    $dir = Get-ScriptInstallDir
    return Join-Path $dir 'PoshAcme-Renew.ps1'
}

function Get-RenewalScheduledTaskCommand {
    <#
        Builds the equivalent Task Scheduler command strings for display in dry-run mode.
        Returns a hashtable: { ActionCmd ; SchtasksCmd }
    #>
    param(
        [string]$TaskName   = "$script:TaskPrefix" + 'RenewAll',
        [string]$ServerName = '',
        [string]$AccountID  = ''
    )
    $renewScript = Get-RenewalScriptPath
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$renewScript`""
    if ($ServerName) { $args += " -ServerName $ServerName" }
    if ($AccountID)  { $args += " -AccountID $AccountID" }

    $actionCmd = "pwsh.exe $args"
    $schtasks  = "schtasks /Create /TN `"$TaskName`" /TR `"$actionCmd`" /SC WEEKLY /D MON /ST 09:00 /RU SYSTEM /RL HIGHEST /F"

    return @{
        ActionCmd   = $actionCmd
        SchtasksCmd = $schtasks
    }
}

function Register-PoshTUIRenewalTask {
    <#
        Registers (or replaces) a Windows Scheduled Task that runs PoshAcme-Renew.ps1.
    #>
    param(
        [Parameter(Mandatory)][string]$TaskName,
        [Parameter(Mandatory)][datetime]$StartTime,
        [ValidateSet('Daily','Weekly','Monthly')][string]$ScheduleType = 'Weekly',
        [string]$DayOfWeek = 'Monday',     # for Weekly
        [int]$DayOfMonth = 1,               # for Monthly (1..28)
        [string]$ServerName = '',
        [string]$AccountID  = ''
    )

    $renewScript = Get-RenewalScriptPath
    if (-not (Test-Path $renewScript)) {
        throw "PoshAcme-Renew.ps1 not found at: $renewScript`nPlease copy it next to PoshAcmeTui.ps1 and try again."
    }

    # Build action
    $actionArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$renewScript`""
    if ($ServerName) { $actionArgs += " -ServerName $ServerName" }
    if ($AccountID)  { $actionArgs += " -AccountID $AccountID" }
    $action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument $actionArgs

    # Build trigger
    switch ($ScheduleType) {
        'Daily' {
            $trigger = New-ScheduledTaskTrigger -Daily -At $StartTime
        }
        'Weekly' {
            $dow = [DayOfWeek]$DayOfWeek
            $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $dow -At $StartTime
        }
        'Monthly' {
            # New-ScheduledTaskTrigger doesn't have a Monthly mode in older versions;
            # use the CIM trigger for monthly on a specific day-of-month.
            $trigger = New-CimInstance -CimClass (Get-CimClass `
                -Namespace 'Root/Microsoft/Windows/TaskScheduler' 'MSFT_TaskTimeTrigger') `
                -ClientOnly
            $trigger.StartBoundary = $StartTime.ToString('yyyy-MM-ddTHH:mm:ss')
            $trigger.Enabled = $true
            # Monthly schedule via MSFT_TaskTrigger's repetition is awkward; fall back to weekly if unsupported
            # Most users will pick Weekly, so we keep monthly simple here.
            throw "Monthly schedule is not supported in this build. Use Weekly or Daily."
        }
    }

    # Run as SYSTEM, highest privileges, wake to run, no time limit
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount `
        -RunLevel Highest

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -WakeToRun `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
        -RestartCount 2 `
        -RestartInterval (New-TimeSpan -Minutes 15)

    # Register (overwrite if exists)
    $fullTaskName = if ($TaskName.StartsWith($script:TaskPrefix)) { $TaskName } else { $script:TaskPrefix + $TaskName }
    Register-ScheduledTask -TaskName $fullTaskName -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings -Force | Out-Null

    return $fullTaskName
}

function Invoke-ManageScheduledTasks {
    Show-Banner
    Write-Step 'Manage scheduled renewal tasks'

    while ($true) {
        $tasks = Get-PoshTUIRenewalTasks
        Write-Host ''
        if (-not $tasks) {
            Write-Warn 'No PoshTUI scheduled renewal tasks found.'
            Write-Host "  (Tasks whose name starts with '$($script:TaskPrefix)' will appear here.)"
        } else {
            Write-Host 'Scheduled renewal tasks:' -ForegroundColor Cyan
            $i = 0
            $tasks | ForEach-Object {
                $i++
                $next  = if ($_.NextRunTime)  { $_.NextRunTime.ToString('yyyy-MM-dd HH:mm') } else { '-' }
                $last  = if ($_.LastRunTime)  { $_.LastRunTime.ToString('yyyy-MM-dd HH:mm') } else { '-' }
                $res   = switch ($_.LastTaskResult) {
                    0    { 'Success' }
                    267011 { 'Task not yet run' }
                    $null { '-' }
                    default { "Err $($_.LastTaskResult)" }
                }
                Write-Host ("  {0,2}: {1,-30} {2,-10} next:{3}  last:{4}  [{5}]" -f `
                    $i, $_.TaskName, $_.State, $next, $last, $res)
            }
        }

        Write-Host ''
        Write-Host 'Options:' -ForegroundColor Cyan
        Write-Host '  c          Create a new scheduled renewal task'
        Write-Host '  r <n>      Run task #n now'
        Write-Host '  l <n>      Show last run log for task #n'
        Write-Host '  d <n>      Delete task #n'
        Write-Host '  x          Back to main menu'
        $line = Read-Host 'Choice'
        if (-not $line) { continue }
        $parts = $line -split '\s+', 2
        $cmd   = $parts[0].ToLower()
        $arg   = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }

        switch ($cmd) {
            'x' { return }
            'c' { Invoke-CreateScheduledTask }
            'r' {
                if (-not $arg -or $arg -notmatch '^\d+$') { Write-Warn 'Provide a number.'; Pause-UI; continue }
                $idx = [int]$arg - 1
                if (-not $tasks -or $idx -lt 0 -or $idx -ge $tasks.Count) { Write-Warn 'Out of range.'; Pause-UI; continue }
                $t = $tasks[$idx]
                try {
                    Start-ScheduledTask -TaskName $t.TaskName -ErrorAction Stop
                    Write-Ok "Task '$($t.TaskName)' started. Use 'l $arg' to tail the log."
                } catch {
                    Write-Err "Failed to start task: $_"
                }
                Pause-UI
            }
            'l' {
                if (-not $arg -or $arg -notmatch '^\d+$') { Write-Warn 'Provide a number.'; Pause-UI; continue }
                $idx = [int]$arg - 1
                if (-not $tasks -or $idx -lt 0 -or $idx -ge $tasks.Count) { Write-Warn 'Out of range.'; Pause-UI; continue }
                $t = $tasks[$idx]
                Show-RenewalLog -TaskName $t.TaskName
            }
            'd' {
                if (-not $arg -or $arg -notmatch '^\d+$') { Write-Warn 'Provide a number.'; Pause-UI; continue }
                $idx = [int]$arg - 1
                if (-not $tasks -or $idx -lt 0 -or $idx -ge $tasks.Count) { Write-Warn 'Out of range.'; Pause-UI; continue }
                $t = $tasks[$idx]
                if (-not (Confirm-Prompt "Delete task '$($t.TaskName)'?")) { continue }
                try {
                    Unregister-ScheduledTask -TaskName $t.TaskName -Confirm:$false -ErrorAction Stop
                    Write-Ok "Task deleted: $($t.TaskName)"
                } catch {
                    Write-Err "Failed to delete task: $_"
                }
                Pause-UI
            }
            default { Write-Warn 'Unknown command.'; Pause-UI }
        }
    }
}

function Invoke-CreateScheduledTask {
    Write-Host ''
    Write-Step 'Create a new scheduled renewal task'

    # ---- Task name ----
    $defaultName = "$($script:TaskPrefix)Renew-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $taskName = Read-Host "Task name (default: $defaultName)"
    if (-not $taskName) { $taskName = $defaultName }
    if (-not $taskName.StartsWith($script:TaskPrefix)) { $taskName = $script:TaskPrefix + $taskName }

    # ---- Pick ACME account ----
    $accounts = Get-AllPAAccounts
    $srvName = ''
    $acctID  = ''
    if ($accounts) {
        Write-Host ''
        Write-Host 'Available ACME accounts:' -ForegroundColor Cyan
        $i = 0
        $accounts | ForEach-Object {
            $i++
            $mail = if ($_.Contact) { $_.Contact } else { '(no contact)' }
            $idShort = if ($_.AccountID.Length -gt 20) { $_.AccountID.Substring(0,20) + '...' } else { $_.AccountID }
            Write-Host ("  {0,2}: [{1,-24}] {2,-22} ({3})" -f $i, $_.ServerName, $idShort, $mail)
        }
        Write-Host "   0: Use the currently active server/account (no -ServerName/-AccountID)"
        $sel = Read-Host 'Pick account (number)'
        if ($sel -match '^\d+$' -and [int]$sel -gt 0) {
            $idx = [int]$sel - 1
            if ($idx -ge 0 -and $idx -lt $accounts.Count) {
                $chosen = $accounts[$idx]
                $srvName = $chosen.ServerName
                $acctID  = $chosen.AccountID
                Write-Host "Using server='$srvName' account='$acctID'" -ForegroundColor Cyan
            } else {
                Write-Warn 'Out of range; will use currently active context.'
            }
        } else {
            Write-Host 'Will use currently active server/account.' -ForegroundColor DarkGray
        }
    } else {
        Write-Warn 'No ACME accounts found. Task will be registered using currently active context.'
    }

    # ---- Schedule ----
    Write-Host ''
    Write-Host 'Schedule options:' -ForegroundColor Cyan
    Write-Host '  1: Weekly on Monday at 09:00  (recommended)'
    Write-Host '  2: Daily at 03:00'
    Write-Host '  3: Weekly on a different day/time'
    $schedChoice = Read-Host 'Choice (default: 1)'
    if (-not $schedChoice) { $schedChoice = '1' }

    $schedType = 'Weekly'
    $startTime = Get-Date '09:00'
    $dayOfWeek = 'Monday'

    switch ($schedChoice) {
        '1' {
            $schedType = 'Weekly'; $startTime = Get-Date '09:00'; $dayOfWeek = 'Monday'
        }
        '2' {
            $schedType = 'Daily';  $startTime = Get-Date '03:00'
        }
        '3' {
            $schedType = 'Weekly'
            $d = Read-Host 'Day of week (Monday/Tuesday/.../Sunday, default Monday)'
            if ($d -and ($d -as [DayOfWeek])) { $dayOfWeek = $d } else { $dayOfWeek = 'Monday' }
            $t = Read-Host 'Start time HH:mm (default 09:00)'
            if ($t) {
                try { $startTime = Get-Date $t } catch { Write-Warn "Invalid time '$t', using 09:00"; $startTime = Get-Date '09:00' }
            }
        }
        default {
            Write-Warn 'Invalid choice, using Weekly Monday 09:00'
        }
    }

    # ---- Confirm ----
    $renewScript = Get-RenewalScriptPath
    Write-Host ''
    Write-Step 'Confirm new scheduled task'
    Write-Host "Task name      : $taskName"
    Write-Host "Script         : $renewScript"
    Write-Host "Server         : $(if ($srvName) { $srvName } else { '(active context)' })"
    Write-Host "Account        : $(if ($acctID)  { $acctID  } else { '(active context)' })"
    $schedLabel = if ($schedType -eq 'Weekly') {
        "$schedType on $dayOfWeek at $($startTime.ToString('HH:mm'))"
    } else {
        "$schedType at $($startTime.ToString('HH:mm'))"
    }
    Write-Host "Schedule       : $schedLabel"
    Write-Host "Run as         : SYSTEM (highest privileges)"
    if (-not (Test-Path $renewScript)) {
        Write-Warn "WARNING: PoshAcme-Renew.ps1 not found at $renewScript"
        Write-Warn '         The task will fail until you copy that file next to PoshAcmeTui.ps1.'
    }
    if (-not (Confirm-Prompt 'Register this task?')) { return }

    # ---- Register ----
    if ($script:DryRun) {
        $cmds = Get-RenewalScheduledTaskCommand -TaskName $taskName -ServerName $srvName -AccountID $acctID
        Write-Warn 'DRY-RUN: no task registered.'
        Write-Host 'Equivalent pwsh.exe action:' -ForegroundColor DarkCyan
        Write-Host "  $($cmds.ActionCmd)" -ForegroundColor Gray
        Write-Host 'Equivalent schtasks.exe registration:' -ForegroundColor DarkCyan
        Write-Host "  $($cmds.SchtasksCmd)" -ForegroundColor Gray
        Pause-UI
        return
    }

    try {
        $registered = Register-PoshTUIRenewalTask -TaskName $taskName -StartTime $startTime `
            -ScheduleType $schedType -DayOfWeek $dayOfWeek -ServerName $srvName -AccountID $acctID
        Write-Ok "Task registered: $registered"
    } catch {
        Write-Err "Failed to register task: $_"
    }
    Pause-UI
}

function Show-RenewalLog {
    param([string]$TaskName)
    Write-Host ''
    Write-Step "Last run log: $TaskName"
    $logPath = 'C:\ProgramData\PoshTUI\renewal.log'
    if (-not (Test-Path $logPath)) {
        Write-Warn "Log file not found: $logPath"
        Write-Host '(The task has either not run yet, or logging failed at runtime.)'
        Pause-UI
        return
    }
    Write-Host "Showing last 50 lines of: $logPath" -ForegroundColor DarkGray
    Write-Host '---'
    try {
        Get-Content $logPath -Tail 50 | ForEach-Object { Write-Host $_ }
    } catch {
        Write-Err "Could not read log: $_"
    }
    Write-Host '---'
    Pause-UI
}

# ============================================================
# MAIN MENU
# ============================================================

function Show-MainMenu {
    while ($true) {
        Show-Banner
        Write-Sep 'Main menu'
        Write-Host ''
        Write-Host '  N: Create certificate (full options)' -ForegroundColor White
        Write-Host '  R: Renew a single certificate'         -ForegroundColor White
        Write-Host '  A: Run all renewals (batch)'           -ForegroundColor White
        Write-Host '  M: Manage renewals'                    -ForegroundColor White
        Write-Host '  B: Browse IIS bindings'                -ForegroundColor White
        Write-Host '  S: Select / create ACME account'       -ForegroundColor White
        Write-Host '  T: Manage scheduled renewal tasks'     -ForegroundColor White
        Write-Host ''
        $dColor = if ($script:DryRun) { 'Green' } else { 'DarkGray' }
        $wColor = if ($script:WhatIf) { 'Green' } else { 'DarkGray' }
        $dState = if ($script:DryRun) { 'ON' } else { 'OFF' }
        $wState = if ($script:WhatIf) { 'ON' } else { 'OFF' }
        Write-Host ("  D: Toggle dry-run mode    (currently: {0})" -f $dState) -ForegroundColor $dColor
        Write-Host ("  W: Toggle What-If mode    (currently: {0})" -f $wState) -ForegroundColor $wColor
        Write-Host ''
        Write-Host '  Q: Quit' -ForegroundColor White
        Write-Host ''
        Write-Sep

        $key = Read-MenuChoice -Prompt 'Choice' -ValidKeys @('N','R','A','M','B','S','T','D','W','Q')
        try {
            switch ($key) {
                'N' { Invoke-CreateCertificate }
                'R' { Invoke-RenewSingle }
                'A' { Invoke-RenewAll }
                'M' { Invoke-ManageRenewals }
                'B' { Invoke-BrowseIISBindings }
                'S' { Invoke-SelectAccount }
                'T' { Invoke-ManageScheduledTasks }
                'D' {
                    $script:DryRun = -not $script:DryRun
                    if ($script:DryRun -and $script:WhatIf) { $script:WhatIf = $false; $WhatIfPreference = $false }
                }
                'W' {
                    $script:WhatIf = -not $script:WhatIf
                    $WhatIfPreference = $script:WhatIf
                    if ($script:WhatIf -and $script:DryRun) { $script:DryRun = $false }
                }
                'Q' { return }
            }
        } catch {
            Write-Err "Unhandled error: $($_.Exception.Message)"
            Pause-UI
        }
    }
}

# ============================================================
# ENTRY POINT
# ============================================================

# 1. Posh-ACME must be installed at the AllUsers location so both the
#    interactive admin and the SYSTEM account can load it from the same path.
Assert-PoshACMEModuleInstalled

# 2. Ensure C:\ProgramData\PoshTUI\ exists with the right ACL, and that the
#    shared Posh-ACME data folder exists too.
Ensure-ProgramDataDir

# 3. Set POSHACME_HOME machine-wide (and for the current process) so both
#    the admin user and SYSTEM read/write the same Posh-ACME store.
Ensure-SharedPoshAcmeHome

# 4. One-time migration: if the user has existing Posh-ACME data in
#    ~/.poshacme AND the shared store is empty, offer to copy it over.
Invoke-PoshAcmeDataMigration | Out-Null

# 5. Load system-wide config from C:\ProgramData\PoshTUI\config.json
Load-Config

try {
    Show-MainMenu
} finally {
    Save-Config
    Clear-Host
    Write-Host 'Goodbye.' -ForegroundColor Cyan
}
