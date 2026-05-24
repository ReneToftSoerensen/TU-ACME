function Invoke-AcmeDnsSetup {
    <#
    .SYNOPSIS
        Guided setup for the ACME-DNS plugin (UC-3.5).
        Returns a hashtable with ACMEDnsServer and ACMEDnsAccountJson ready for New-PACertificate,
        or $null if the user cancels.
    #>
    param(
        [string[]] $Domains
    )

    Invoke-ConsoleClear
    Write-Host '  === ACME-DNS Setup ===' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  ACME-DNS is a dedicated DNS server for ACME challenges.' -ForegroundColor Gray
    Write-Host '  It only requires a single permanent CNAME record in your DNS zone.' -ForegroundColor Gray
    Write-Host ''

    # Step 1: ACME-DNS server URL
    $server = _Get-AcmeDnsServer
    if ($server -eq $null) { return $null }

    # Step 2: New or existing account
    $accountJson = _Get-AcmeDnsAccount -Server $server -Domains $Domains
    if ($accountJson -eq $null) { return $null }

    # Step 3: Show CNAME instruction and wait for confirmation
    $cnameOk = _Show-CnameInstruction -Domains $Domains -AccountData $accountJson
    if (-not $cnameOk) { return $null }

    # Step 4: Save credentials encrypted
    $jsonPath = _Save-AcmeDnsAccount -AccountData $accountJson -Domains $Domains
    if ($jsonPath -eq $null) { return $null }

    Write-Host ''
    Write-Host '  ACME-DNS setup completed.' -ForegroundColor Green

    return @{
        ACMEDnsServer      = $server
        ACMEDnsAccountJson = $jsonPath
    }
}

function _Get-AcmeDnsServer {
    Write-Host '  ACME-DNS server URL:' -ForegroundColor Gray
    Write-Host '  Examples:' -ForegroundColor DarkGray
    Write-Host '    https://auth.acme-dns.io       (public)' -ForegroundColor DarkGray
    Write-Host '    https://acmedns.example.com    (self-hosted)' -ForegroundColor DarkGray
    Write-Host ''

    while ($true) {
        $url = Read-Host '  Server URL'
        if ($url -eq '') {
            Write-Host '  URL is required.' -ForegroundColor Red
            continue
        }

        # Validate that the server responds
        Write-Host '  Testing connection...' -ForegroundColor Cyan -NoNewline
        try {
            $resp = Invoke-WebRequest -Uri "$url/register" -Method Get `
                -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            Write-Host ' OK' -ForegroundColor Green
            return $url.TrimEnd('/')
        } catch {
            # 405 Method Not Allowed is expected for GET /register — the server is responding
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode.value__ -in @(405, 400)) {
                Write-Host ' OK' -ForegroundColor Green
                return $url.TrimEnd('/')
            }
            Write-Host ' ERROR' -ForegroundColor Red
            Write-Host "  Could not connect: $_" -ForegroundColor Red
            if (-not (Confirm-YesNo '  Try again? (Y/N)')) { return $null }
        }
    }
}

function _Get-AcmeDnsAccount {
    param([string] $Server, [string[]] $Domains)

    Write-Host ''
    if (Confirm-YesNo '  Do you already have an ACME-DNS account for this domain? (Y/N)') {
        return _Load-ExistingAccount
    }

    return _Register-NewAccount -Server $Server
}

function _Register-NewAccount {
    param([string] $Server)

    Write-Host ''
    Write-Host '  Registering new account on ' -NoNewline -ForegroundColor Cyan
    Write-Host $Server -ForegroundColor White -NoNewline
    Write-Host '...' -ForegroundColor Cyan

    try {
        $response = Invoke-RestMethod -Uri "$Server/register" -Method Post `
            -ContentType 'application/json' -Body '{}' `
            -TimeoutSec 30 -ErrorAction Stop

        Write-Host ''
        Write-Host '  Account created!' -ForegroundColor Green
        Write-Host ''

        $w = [Math]::Max((Get-ConsoleWidth) - 4, 60)
        $border = '+' + ('-' * ($w - 2)) + '+'
        Write-Host "  $border" -ForegroundColor DarkCyan

        $fields = [ordered]@{
            'Username'   = $response.username
            'Password'   = $response.password
            'Subdomain'  = $response.subdomain
            'FullDomain' = $response.fulldomain
        }
        foreach ($kv in $fields.GetEnumerator()) {
            $label = "| $($kv.Key.PadRight(12)) $($kv.Value)"
            Write-Host "  $($label.PadRight($w - 1))| " -ForegroundColor White
        }
        Write-Host "  $border" -ForegroundColor DarkCyan

        return $response
    } catch {
        Write-Host ''
        Write-Host "  [ERROR] Registration failed: $_" -ForegroundColor Red
        Write-Host '  Verify that the server accepts new registrations.' -ForegroundColor Yellow
        Write-Host ''
        Wait-AnyKey
        return $null
    }
}

function _Load-ExistingAccount {
    Write-Host ''
    Write-Host '  Enter path to existing account JSON:' -ForegroundColor Gray
    $path = Read-Host '  JSON path'

    if (-not (Test-Path $path)) {
        Write-Host "  The file '$path' was not found." -ForegroundColor Red
        return $null
    }

    try {
        $data = Get-Content -Path $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not ($data.username -and $data.password -and $data.fulldomain)) {
            Write-Host '  JSON is missing required fields (username, password, fulldomain).' -ForegroundColor Red
            return $null
        }
        Write-Host "  Loaded. Username: $($data.username)" -ForegroundColor Green
        Write-Host "  FullDomain: $($data.fulldomain)" -ForegroundColor White
        return $data
    } catch {
        Write-Host "  Error reading JSON: $_" -ForegroundColor Red
        return $null
    }
}

function _Show-CnameInstruction {
    param($Domains, $AccountData)

    Invoke-ConsoleClear
    Write-Host '  === ACTION REQUIRED ===' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  Create the following CNAME record(s) at your DNS provider.' -ForegroundColor White
    Write-Host '  This is done ONLY ONCE and is permanent.' -ForegroundColor White
    Write-Host ''

    $w      = [Math]::Max((Get-ConsoleWidth) - 4, 72)
    $border = '+' + ('-' * ($w - 2)) + '+'

    Write-Host "  $border" -ForegroundColor Yellow
    foreach ($domain in $Domains) {
        # Strip wildcard prefix for the CNAME name
        $baseDomain  = $domain -replace '^\*\.', ''
        $cnameName   = "_acme-challenge.$baseDomain"
        $cnameTarget = "$($AccountData.fulldomain)."

        Write-Host "  | Domain: $domain" -ForegroundColor White
        Write-Host "  |   Name:  $cnameName" -ForegroundColor Cyan
        Write-Host "  |   Type:  CNAME" -ForegroundColor Cyan
        Write-Host "  |   Value: $cnameTarget" -ForegroundColor Cyan
        Write-Host "  |   TTL:   300" -ForegroundColor Cyan
        if ($Domains.Count -gt 1 -and $domain -ne $Domains[-1]) {
            Write-Host "  |" -ForegroundColor Yellow
        }
    }
    Write-Host "  $border" -ForegroundColor Yellow

    Write-Host ''
    Write-Host '  Press [Enter] when the CNAME record has been created and propagated.' -ForegroundColor DarkGray
    Write-Host '  Press [ESC] to cancel.' -ForegroundColor DarkGray

    while ($true) {
        $key = Invoke-ConsoleReadKey
        if ($key.Key -eq [ConsoleKey]::Enter)  { return $true }
        if ($key.Key -eq [ConsoleKey]::Escape) { return $false }
    }
}

function _Save-AcmeDnsAccount {
    param($AccountData, [string[]] $Domains)

    $accountDir = Join-Path $env:ProgramData 'TU-ACME\acmedns-accounts'
    New-Item -ItemType Directory -Path $accountDir -Force | Out-Null

    # Use the primary domain as the file name (sanitized)
    $primaryDomain  = ($Domains[0] -replace '^\*\.', '') -replace '[^a-zA-Z0-9\-]', '_'
    $jsonPath       = Join-Path $accountDir "$primaryDomain.json"

    try {
        $AccountData | ConvertTo-Json -Compress | Set-Content -Path $jsonPath -Encoding UTF8
        Write-Host "  Credentials saved: $jsonPath" -ForegroundColor Green

        # DPAPI-encrypted backup via Export-Clixml
        $xmlPath = $jsonPath -replace '\.json$', '.xml'
        $serverProp = $AccountData.PSObject.Properties['server']
        [PSCustomObject]@{
            Server     = if ($serverProp -ne $null) { $serverProp.Value } else { $null }
            Username   = $AccountData.username
            Password   = $AccountData.password
            Subdomain  = $AccountData.subdomain
            FullDomain = $AccountData.fulldomain
        } | Export-Clixml -Path $xmlPath
        Write-Host '  Encrypted backup saved (DPAPI).' -ForegroundColor DarkGray

        return $jsonPath
    } catch {
        Write-Host "  Error saving credentials: $_" -ForegroundColor Red
        return $null
    }
}

function Get-AcmeDnsAccountPath {
    <#
    .SYNOPSIS
        Returns the path to a saved ACME-DNS account JSON for a given domain.
        Returns $null if no account is found.
    #>
    param([string] $Domain)

    $baseDomain = ($Domain -replace '^\*\.', '') -replace '[^a-zA-Z0-9\-]', '_'
    $jsonPath   = Join-Path $env:ProgramData "TU-ACME\acmedns-accounts\$baseDomain.json"

    if (Test-Path $jsonPath) { return $jsonPath }
    return $null
}
