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
        Invoke-ConsoleClear

        Write-Host '  === Account Management ===' -ForegroundColor Cyan
        Write-Host ''

        if ($accounts.Count -eq 0) {
            Write-Host '  No ACME accounts found.' -ForegroundColor Yellow
            Write-Host ''
        } else {
            $colorRule = {
                param($row)
                if ($row.status -eq 'valid') { 'Green' } else { 'Yellow' }
            }
            Show-Table -Data $accounts `
                -Columns @('id', 'contact', 'status') `
                -Headers @('ID', 'Contact', 'Status') `
                -Widths  @(20, 40, 10) `
                -ColorRule $colorRule
            Write-Host ''
        }

        $options = @(
            '1. Create new account',
            '2. Switch active account',
            '3. Switch to Staging',
            'B. Back'
        )
        $sel = Show-Menu -Title 'Account Management' -Options $options

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
    Invoke-ConsoleClear
    Write-Host '  === Create new ACME account ===' -ForegroundColor Cyan
    Write-Host ''

    $email = Read-Host '  Email address'
    if ($email -eq '') { return }

    $serverOptions = @(
        "1. Let's Encrypt (Production)",
        "2. Let's Encrypt (Staging)",
        '3. Other server (enter manually)'
    )
    $serverSel = Show-Menu -Title 'Select ACME server' -Options $serverOptions

    $server = switch ($serverSel) {
        0 { 'LE_PROD' }
        1 { 'LE_STAGE' }
        2 {
            Invoke-ConsoleClear
            Write-Host '  === Enter ACME server URL ===' -ForegroundColor Cyan
            Write-Host ''
            Read-Host '  Server URL'
        }
        default { return }
    }

    Write-Host ''
    Write-Host "  Creating account with $email ..." -ForegroundColor Cyan

    try {
        Set-PAServer $server
        New-PAAccount -AcceptTOS -Contact "mailto:$email" | Out-Null
        Write-Host '  Account created.' -ForegroundColor Green
    } catch {
        Write-Host "  Error: $_" -ForegroundColor Red
    }

    Write-Host ''
    Wait-AnyKey
}

function _Set-ActiveAccount {
    param([object[]] $Accounts)

    if ($Accounts.Count -eq 0) {
        Write-Host '  No accounts to select.' -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        return
    }

    $options = $Accounts | ForEach-Object { "$($_.id) | $($_.contact)" }
    $sel     = Show-Menu -Title 'Select active account' -Options $options

    if ($sel -lt 0) { return }

    try {
        Set-PAAccount -ID $Accounts[$sel].id | Out-Null
        Write-Host "  Active account: $($Accounts[$sel].id)" -ForegroundColor Green
        Start-Sleep -Seconds 1
    } catch {
        Write-Host "  Error switching account: $_" -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}

function _Toggle-StagingAccount {
    Invoke-ConsoleClear
    Write-Host '  === Staging toggle ===' -ForegroundColor Cyan
    Write-Host ''

    $current = Get-PAServer 2>$null
    if ($current -and $current.location -match 'staging') {
        Write-Host "  Switching to PRODUCTION ..." -ForegroundColor Yellow
        Set-PAServer LE_PROD
        Write-Host "  Active server: Let's Encrypt Production" -ForegroundColor Green
    } else {
        Write-Host "  Switching to STAGING ..." -ForegroundColor Yellow
        Set-PAServer LE_STAGE
        Write-Host "  Active server: Let's Encrypt Staging" -ForegroundColor Cyan
    }

    Write-Host ''
    Wait-AnyKey
}
