function Invoke-AccountMenu {
    param([switch] $StagingToggle)

    if ($StagingToggle) {
        _Toggle-StagingAccount
        return
    }

    while ($true) {
        $accounts   = @(Get-PAAccount -List 2>$null)
        $activeId   = ''
        try { $activeId = (Get-PAAccount 2>$null).id } catch {}
        $nameMap    = _Get-AccountNameMap

        Invoke-ConsoleClear
        Write-Host '  === Account Management ===' -ForegroundColor Cyan
        Write-Host ''

        if ($accounts.Count -eq 0) {
            Write-Host '  No ACME accounts found.' -ForegroundColor Yellow
            Write-Host ''
        } else {
            $rows = $accounts | ForEach-Object {
                [PSCustomObject]@{
                    Active  = if ($_.id -eq $activeId) { '*' } else { ' ' }
                    ID      = $_.id
                    Name    = _Get-AccountFriendlyName -Id $_.id -Map $nameMap
                    Contact = ($_.contact | ForEach-Object { $_ -replace '^mailto:', '' }) -join ', '
                    Status  = $_.status
                }
            }
            $colorRule = {
                param($row)
                if ($row.Active -eq '*')        { 'Cyan' }
                elseif ($row.Status -eq 'valid') { 'Green' } else { 'Yellow' }
            }
            Show-Table -Data $rows `
                -Columns @('Active', 'ID', 'Name', 'Contact', 'Status') `
                -Headers @(' ', 'ID', 'Name', 'Contact', 'Status') `
                -Widths  @(2, 16, 24, 30, 8) `
                -ColorRule $colorRule
            Write-Host ''
        }

        $options = @(
            '1. Create new account',
            '2. Switch active account',
            '3. Rename account',
            '4. Switch to Staging',
            'B. Back'
        )
        $sel = Show-Menu -Title 'Account Management' -Options $options

        switch ($sel) {
            -1 { return }
            0  { _New-ACMEAccount }
            1  { _Set-ActiveAccount -Accounts $accounts -ActiveId $activeId -NameMap $nameMap }
            2  { _Rename-Account -Accounts $accounts -NameMap $nameMap }
            3  { _Toggle-StagingAccount }
            4  { return }
        }
    }
}

function _Get-AccountNameMap {
    $config = Get-TUACMEConfig
    if ($config.Accounts) { return $config.Accounts }
    return [PSCustomObject]@{}
}

function _Get-AccountFriendlyName {
    param([string] $Id, $Map)
    if (-not $Map) { return '' }
    $prop = $Map.PSObject.Properties[$Id]
    if ($prop -and $prop.Value -and $prop.Value.Name) { return $prop.Value.Name }
    return ''
}

function _Set-AccountFriendlyName {
    param([string] $Id, [string] $Name)
    $config = Get-TUACMEConfig
    if (-not $config.Accounts) {
        $config | Add-Member -NotePropertyName 'Accounts' -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    $entry = [PSCustomObject]@{ Name = $Name }
    $config.Accounts | Add-Member -NotePropertyName $Id -NotePropertyValue $entry -Force
    Set-TUACMEConfig -Config $config
}

function _New-ACMEAccount {
    Invoke-ConsoleClear
    Write-Host '  === Create new ACME account ===' -ForegroundColor Cyan
    Write-Host ''

    $email = Read-Host '  Email address'
    if ($email -eq '') { return }

    $friendlyName = Read-Host '  Friendly name (optional, blank = none)'

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
        # Posh-ACME's New-PAAccount returns the new account on some
        # versions and nothing on others. Don't rely on the return —
        # query Get-PAAccount after the call to get the source of truth.
        New-PAAccount -AcceptTOS -Contact "mailto:$email" | Out-Null
        $newAccount = Get-PAAccount 2>$null

        if (-not $newAccount) {
            Write-Host '  Error: account creation appears to have failed.' -ForegroundColor Red
            Write-Host '  Get-PAAccount returns nothing after New-PAAccount. Check the ACME server URL,' -ForegroundColor Yellow
            Write-Host '  the contact email format, and network connectivity to the ACME directory.' -ForegroundColor Yellow
            Write-Host ''
            Wait-AnyKey
            return
        }

        # Force the new account to be the active one. Without this, Posh-ACME
        # may leave the previous server's account selected, which causes
        # Get-PAAccount -List in the outer menu loop to return an empty set
        # on the just-switched server — making the new account "invisible"
        # for Rename / Switch until you reopen the menu.
        Set-PAAccount -ID $newAccount.id | Out-Null

        if ($friendlyName -ne '') {
            _Set-AccountFriendlyName -Id $newAccount.id -Name $friendlyName.Trim()
        }
        Write-Host "  Account created: $($newAccount.id)" -ForegroundColor Green
        if ($friendlyName -ne '') {
            Write-Host "  Name:            $($friendlyName.Trim())" -ForegroundColor Green
        }
    } catch {
        Write-Host "  Error: $_" -ForegroundColor Red
    }

    Write-Host ''
    Wait-AnyKey
}

function _Set-ActiveAccount {
    param(
        [object[]] $Accounts,
        [string]   $ActiveId = '',
        $NameMap = $null
    )

    if ($Accounts.Count -eq 0) {
        Write-Host '  No accounts to select.' -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        return
    }

    $options = $Accounts | ForEach-Object {
        $marker  = if ($_.id -eq $ActiveId) { '*' } else { ' ' }
        $name    = _Get-AccountFriendlyName -Id $_.id -Map $NameMap
        $namePart = if ($name) { " | $name" } else { '' }
        "$marker $($_.id)$namePart | $($_.contact -join ', ')"
    }
    $sel = Show-Menu -Title 'Select active account' -Options $options
    if ($sel -lt 0) { return }

    $picked = $Accounts[$sel]
    if ($picked.id -eq $ActiveId) {
        Write-Host "  '$($picked.id)' is already the active account." -ForegroundColor DarkGray
        Start-Sleep -Seconds 1
        return
    }

    try {
        Set-PAAccount -ID $picked.id | Out-Null
        $now = Get-PAAccount 2>$null
        if ($now -and $now.id -eq $picked.id) {
            $friendly = _Get-AccountFriendlyName -Id $now.id -Map $NameMap
            $tail     = if ($friendly) { " ($friendly)" } else { '' }
            Write-Host "  Active account is now: $($now.id)$tail" -ForegroundColor Green
        } else {
            Write-Host "  Set-PAAccount returned but the active account did not change." -ForegroundColor Yellow
            Write-Host "  Current active ID: $($now.id)" -ForegroundColor DarkGray
        }
        Start-Sleep -Seconds 2
    } catch {
        Write-Host "  Error switching account: $_" -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}

function _Rename-Account {
    param([object[]] $Accounts, $NameMap = $null)

    if ($Accounts.Count -eq 0) {
        Write-Host '  No accounts to rename.' -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        return
    }

    $options = $Accounts | ForEach-Object {
        $name    = _Get-AccountFriendlyName -Id $_.id -Map $NameMap
        $tail    = if ($name) { " | $name" } else { '' }
        "$($_.id)$tail | $($_.contact -join ', ')"
    }
    $sel = Show-Menu -Title 'Rename account' -Options $options
    if ($sel -lt 0) { return }

    $picked  = $Accounts[$sel]
    $current = _Get-AccountFriendlyName -Id $picked.id -Map $NameMap
    Write-Host ''
    if ($current) { Write-Host "  Current name: $current" -ForegroundColor DarkGray }

    $newName = Read-Host '  New name (blank = clear)'
    _Set-AccountFriendlyName -Id $picked.id -Name $newName.Trim()
    Write-Host "  Saved." -ForegroundColor Green
    Start-Sleep -Seconds 1
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
