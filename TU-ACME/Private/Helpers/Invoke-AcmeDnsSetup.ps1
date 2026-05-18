function Invoke-AcmeDnsSetup {
    <#
    .SYNOPSIS
        Guidet opsætning af ACME-DNS plugin (UC-3.5).
        Returnerer et hashtable med ACMEDnsServer og ACMEDnsAccountJson klar til New-PACertificate,
        eller $null hvis brugeren afbryder.
    #>
    param(
        [string[]] $Domains
    )

    [Console]::Clear()
    Write-Host '  === ACME-DNS Opsætning ===' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  ACME-DNS er en dedikeret DNS-server til ACME-challenges.' -ForegroundColor Gray
    Write-Host '  Den kræver kun én permanent CNAME-record i din DNS-zone.' -ForegroundColor Gray
    Write-Host ''

    # Trin 1: ACME-DNS server URL
    $server = _Get-AcmeDnsServer
    if ($server -eq $null) { return $null }

    # Trin 2: Ny konto eller eksisterende
    $accountJson = _Get-AcmeDnsAccount -Server $server -Domains $Domains
    if ($accountJson -eq $null) { return $null }

    # Trin 3: Vis CNAME-instruktion og vent på bekræftelse
    if (-not _Show-CnameInstruction -Domains $Domains -AccountData $accountJson) { return $null }

    # Trin 4: Gem credentials krypteret
    $jsonPath = _Save-AcmeDnsAccount -AccountData $accountJson -Domains $Domains
    if ($jsonPath -eq $null) { return $null }

    Write-Host ''
    Write-Host '  ACME-DNS opsætning fuldfoert.' -ForegroundColor Green

    return @{
        ACMEDnsServer      = $server
        ACMEDnsAccountJson = $jsonPath
    }
}

function _Get-AcmeDnsServer {
    Write-Host '  ACME-DNS server URL:' -ForegroundColor Gray
    Write-Host '  Eksempler:' -ForegroundColor DarkGray
    Write-Host '    https://auth.acme-dns.io       (offentlig)' -ForegroundColor DarkGray
    Write-Host '    https://acmedns.eksempel.dk    (selvhostet)' -ForegroundColor DarkGray
    Write-Host ''

    while ($true) {
        $url = Read-Host '  Server URL'
        if ($url -eq '') {
            Write-Host '  URL er paakraevet.' -ForegroundColor Red
            continue
        }

        # Valider at serveren svarer
        Write-Host '  Tester forbindelse...' -ForegroundColor Cyan -NoNewline
        try {
            $resp = Invoke-WebRequest -Uri "$url/register" -Method Get `
                -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            Write-Host ' OK' -ForegroundColor Green
            return $url.TrimEnd('/')
        } catch {
            # 405 Method Not Allowed er forventet for GET /register — serveren svarer
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode.value__ -in @(405, 400)) {
                Write-Host ' OK' -ForegroundColor Green
                return $url.TrimEnd('/')
            }
            Write-Host ' FEJL' -ForegroundColor Red
            Write-Host "  Kunne ikke forbinde: $_" -ForegroundColor Red
            $retry = Read-Host '  Prøv igen? (J/N)'
            if ($retry -notmatch '^[Jj]') { return $null }
        }
    }
}

function _Get-AcmeDnsAccount {
    param([string] $Server, [string[]] $Domains)

    Write-Host ''
    $existing = Read-Host '  Har du allerede en ACME-DNS konto til dette domæne? (J/N)'

    if ($existing -match '^[Jj]') {
        return _Load-ExistingAccount
    }

    return _Register-NewAccount -Server $Server
}

function _Register-NewAccount {
    param([string] $Server)

    Write-Host ''
    Write-Host '  Registrerer ny konto på ' -NoNewline -ForegroundColor Cyan
    Write-Host $Server -ForegroundColor White -NoNewline
    Write-Host '...' -ForegroundColor Cyan

    try {
        $response = Invoke-RestMethod -Uri "$Server/register" -Method Post `
            -ContentType 'application/json' -Body '{}' `
            -TimeoutSec 30 -ErrorAction Stop

        Write-Host ''
        Write-Host '  Konto oprettet!' -ForegroundColor Green
        Write-Host ''

        $w = [Math]::Max([Console]::WindowWidth - 4, 60)
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
        Write-Host "  [FEJL] Registrering fejlede: $_" -ForegroundColor Red
        Write-Host '  Kontrollér at serveren accepterer nye registreringer.' -ForegroundColor Yellow
        Write-Host ''
        Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
        Invoke-ConsoleWaitKey
        return $null
    }
}

function _Load-ExistingAccount {
    Write-Host ''
    Write-Host '  Angiv sti til eksisterende konto-JSON:' -ForegroundColor Gray
    $path = Read-Host '  JSON-sti'

    if (-not (Test-Path $path)) {
        Write-Host "  Filen '$path' blev ikke fundet." -ForegroundColor Red
        return $null
    }

    try {
        $data = Get-Content -Path $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not ($data.username -and $data.password -and $data.fulldomain)) {
            Write-Host '  JSON mangler paakaevede felter (username, password, fulldomain).' -ForegroundColor Red
            return $null
        }
        Write-Host "  Indlaest. Username: $($data.username)" -ForegroundColor Green
        Write-Host "  FullDomain: $($data.fulldomain)" -ForegroundColor White
        return $data
    } catch {
        Write-Host "  Fejl ved laesning af JSON: $_" -ForegroundColor Red
        return $null
    }
}

function _Show-CnameInstruction {
    param($Domains, $AccountData)

    [Console]::Clear()
    Write-Host '  === HANDLING PAAKRAEVET ===' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  Opret foelgende CNAME-record(s) hos din DNS-provider.' -ForegroundColor White
    Write-Host '  Dette goeres KUN EN GANG og er permanent.' -ForegroundColor White
    Write-Host ''

    $w      = [Math]::Max([Console]::WindowWidth - 4, 72)
    $border = '+' + ('-' * ($w - 2)) + '+'

    Write-Host "  $border" -ForegroundColor Yellow
    foreach ($domain in $Domains) {
        # Strip wildcard prefix til CNAME-navn
        $baseDomain  = $domain -replace '^\*\.', ''
        $cnameName   = "_acme-challenge.$baseDomain"
        $cnameTarget = "$($AccountData.fulldomain)."

        Write-Host "  | Domæne: $domain" -ForegroundColor White
        Write-Host "  |   Navn:  $cnameName" -ForegroundColor Cyan
        Write-Host "  |   Type:  CNAME" -ForegroundColor Cyan
        Write-Host "  |   Vaerdi: $cnameTarget" -ForegroundColor Cyan
        Write-Host "  |   TTL:   300" -ForegroundColor Cyan
        if ($Domains.Count -gt 1 -and $domain -ne $Domains[-1]) {
            Write-Host "  |" -ForegroundColor Yellow
        }
    }
    Write-Host "  $border" -ForegroundColor Yellow

    Write-Host ''
    Write-Host '  Tryk [Enter] naer CNAME-recorden er oprettet og propageret.' -ForegroundColor DarkGray
    Write-Host '  Tryk [ESC] for at afbryde.' -ForegroundColor DarkGray

    while ($true) {
        $key = Invoke-ConsoleReadKey
        if ($key.Key -eq [ConsoleKey]::Enter)  { return $true }
        if ($key.Key -eq [ConsoleKey]::Escape) { return $false }
    }
}

function _Save-AcmeDnsAccount {
    param($AccountData, [string[]] $Domains)

    $accountDir = Join-Path $env:ProgramData 'TU-ACME\acmedns-accounts'
    if (-not (Test-Path $accountDir)) {
        New-Item -ItemType Directory -Path $accountDir -Force | Out-Null
    }

    # Brug primære domæne som filnavn (saniteret)
    $primaryDomain  = ($Domains[0] -replace '^\*\.', '') -replace '[^a-zA-Z0-9\-\.]', '_'
    $jsonPath       = Join-Path $accountDir "$primaryDomain.json"

    try {
        $AccountData | ConvertTo-Json -Compress | Set-Content -Path $jsonPath -Encoding UTF8
        Write-Host "  Credentials gemt: $jsonPath" -ForegroundColor Green

        # DPAPI-krypteret backup via Export-Clixml
        $xmlPath = $jsonPath -replace '\.json$', '.xml'
        [PSCustomObject]@{
            Server     = $AccountData.PSObject.Properties['server']?.Value
            Username   = $AccountData.username
            Password   = $AccountData.password
            Subdomain  = $AccountData.subdomain
            FullDomain = $AccountData.fulldomain
        } | Export-Clixml -Path $xmlPath
        Write-Host '  Krypteret backup gemt (DPAPI).' -ForegroundColor DarkGray

        return $jsonPath
    } catch {
        Write-Host "  Fejl ved gemning af credentials: $_" -ForegroundColor Red
        return $null
    }
}

function Get-AcmeDnsAccountPath {
    <#
    .SYNOPSIS
        Returnerer stien til en gemt ACME-DNS konto-JSON for et givet domæne.
        Returnerer $null hvis ingen konto er fundet.
    #>
    param([string] $Domain)

    $baseDomain = ($Domain -replace '^\*\.', '') -replace '[^a-zA-Z0-9\-\.]', '_'
    $jsonPath   = Join-Path $env:ProgramData "TU-ACME\acmedns-accounts\$baseDomain.json"

    if (Test-Path $jsonPath) { return $jsonPath }
    return $null
}
