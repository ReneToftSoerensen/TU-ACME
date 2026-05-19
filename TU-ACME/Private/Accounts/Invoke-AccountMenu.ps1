function Invoke-AccountMenu {
    param([switch] $StagingToggle)

    $stagingUrl    = 'https://acme-staging-v02.api.letsencrypt.org/directory'
    $productionUrl = 'https://acme-v02.api.letsencrypt.org/directory'

    if ($StagingToggle) {
        _Toggle-StagingAccount
        return
    }

    while ($true) {
        $accounts = @(Get-PAAccount -List 2>$null)
        [Console]::Clear()

        Write-Host '  === Kontostyring ===' -ForegroundColor Cyan
        Write-Host ''

        if ($accounts.Count -eq 0) {
            Write-Host '  Ingen ACME-konti fundet.' -ForegroundColor Yellow
            Write-Host ''
        } else {
            $colorRule = {
                param($row)
                if ($row.status -eq 'valid') { 'Green' } else { 'Yellow' }
            }
            Show-Table -Data $accounts `
                -Columns @('id', 'contact', 'status') `
                -Headers @('ID', 'Kontakt', 'Status') `
                -Widths  @(20, 40, 10) `
                -ColorRule $colorRule
            Write-Host ''
        }

        $options = @(
            '1. Opret ny konto',
            '2. Skift aktiv konto',
            '3. Skift til Staging',
            'B. Tilbage'
        )
        $sel = Show-Menu -Title 'Kontostyring' -Options $options

        switch ($sel) {
            -1 { return }
            0  { _New-ACMEAccount }
            1  { _Set-ActiveAccount -Accounts $accounts }
            2  { _Toggle-StagingAccount }
            3  { return }
        }
    }
}

function _New-ACMEAccount {
    [Console]::Clear()
    Write-Host '  === Opret ny ACME-konto ===' -ForegroundColor Cyan
    Write-Host ''

    $email = Read-Host '  E-mail adresse'
    if ($email -eq '') { return }

    $serverOptions = @(
        "1. Let's Encrypt (Produktion)",
        "2. Let's Encrypt (Staging)",
        '3. Anden server (angiv manuelt)'
    )
    $serverSel = Show-Menu -Title 'Vaelg ACME-server' -Options $serverOptions

    $server = switch ($serverSel) {
        0 { 'LE_PROD' }
        1 { 'LE_STAGE' }
        2 { Read-Host '  Server URL' }
        default { return }
    }

    Write-Host ''
    Write-Host "  Opretter konto med $email ..." -ForegroundColor Cyan

    try {
        $acctParams = @{
            AcceptTOS = $true
            Contact   = "mailto:$email"
        }
        if ($server -notin @('LE_PROD', 'LE_STAGE')) {
            $acctParams['DirectoryUrl'] = $server
        } else {
            Set-PAServer $server
        }
        New-PAAccount @acctParams | Out-Null
        Write-Host '  Konto oprettet.' -ForegroundColor Green
    } catch {
        Write-Host "  Fejl: $_" -ForegroundColor Red
    }

    Write-Host ''
    Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
    [Console]::ReadKey($true) | Out-Null
}

function _Set-ActiveAccount {
    param([object[]] $Accounts)

    if ($Accounts.Count -eq 0) {
        Write-Host '  Ingen konti at vaelge.' -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        return
    }

    $options = $Accounts | ForEach-Object { "$($_.id) | $($_.contact)" }
    $sel     = Show-Menu -Title 'Vaelg aktiv konto' -Options $options

    if ($sel -lt 0) { return }

    try {
        Set-PAAccount -ID $Accounts[$sel].id | Out-Null
        Write-Host "  Aktiv konto: $($Accounts[$sel].id)" -ForegroundColor Green
        Start-Sleep -Seconds 1
    } catch {
        Write-Host "  Fejl ved kontoskift: $_" -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}

function _Toggle-StagingAccount {
    [Console]::Clear()
    Write-Host '  === Staging-toggle ===' -ForegroundColor Cyan
    Write-Host ''

    $current = Get-PAServer 2>$null
    if ($current -and $current.location -match 'staging') {
        Write-Host "  Skifter til PRODUKTION ..." -ForegroundColor Yellow
        Set-PAServer LE_PROD
        Write-Host "  Aktiv server: Let's Encrypt Produktion" -ForegroundColor Green
    } else {
        Write-Host "  Skifter til STAGING ..." -ForegroundColor Yellow
        Set-PAServer LE_STAGE
        Write-Host "  Aktiv server: Let's Encrypt Staging" -ForegroundColor Cyan
    }

    Write-Host ''
    Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
    [Console]::ReadKey($true) | Out-Null
}
