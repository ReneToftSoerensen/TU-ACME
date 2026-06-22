<#
    Accounts.ps1 - ACME account/server selection and creation (S menu).
#>

function Invoke-SelectAccount {
    Show-Banner
    Write-Step 'Manage ACME accounts'

    $ctx     = Get-CurrentPAContext
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
        foreach ($a in $accounts) {
            $i++
            $mail    = if ($a.Contact) { $a.Contact } else { '(no contact)' }
            $idShort = if ($a.AccountID -and $a.AccountID.Length -gt 20) { $a.AccountID.Substring(0, 20) + '...' } else { $a.AccountID }
            $active  = if ($ctx.Server -and $ctx.Account -and
                           $ctx.Server.Name -eq $a.ServerName -and
                           $ctx.Account.id -eq $a.AccountID) { ' *' } else { '  ' }
            $warn    = if ($a.NeedsAltEncryption) { '  [!] alt-encryption OFF' } else { '' }
            Write-Host ("$active{0,2}: [{1,-24}] {2,-22} {3}  ({4})  {5}/{6}{7}" -f `
                $i, $a.ServerName, $idShort, $a.Status, $mail, $a.KeyAlg, $a.KeyLength, $warn)
        }
        Write-Host ''
        Write-Host '  * = currently active' -ForegroundColor DarkGray
        if ($accounts | Where-Object { $_.NeedsAltEncryption }) {
            Write-Host '  [!] = account stores secure plugin args but portable (AES) encryption is OFF;' -ForegroundColor Yellow
            Write-Host '        renewal under the SYSTEM scheduled task will fail to decrypt. Use ''a <n>'' to fix.' -ForegroundColor Yellow
        }
    }

    Write-Host ''
    Write-Host 'Options:' -ForegroundColor Cyan
    Write-Host '  <number>   Select that account (also activates its server)'
    Write-Host '  n          Create a new account on a chosen server'
    Write-Host '  a <number> Enable portable (AES) plugin encryption on that account'
    Write-Host '  c          Cancel'
    Write-Host ''
    $line = Read-Host 'Choice'
    if (-not $line) { return }
    $parts = $line.Trim() -split '\s+', 2
    $key   = $parts[0].ToLower()
    $arg   = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }

    if ($key -eq 'c') { return }
    if ($key -eq 'n') { Invoke-CreateNewAccount; return }

    if ($key -eq 'a') {
        if (-not $arg -or $arg -notmatch '^\d+$') { Write-Warn 'Provide a number.'; Wait-UI; return }
        $idx = [int]$arg - 1
        if (-not $accounts -or $idx -lt 0 -or $idx -ge $accounts.Count) { Write-Warn 'Out of range.'; Wait-UI; return }
        Enable-PAAccountAltEncryption -Account $accounts[$idx]
        Wait-UI
        return
    }

    if ($key -match '^\d+$') {
        $idx = [int]$key - 1
        if (-not $accounts -or $idx -lt 0 -or $idx -ge $accounts.Count) { Write-Warn 'Number out of range.'; Wait-UI; return }
        $sel    = $accounts[$idx]
        $srvArg = if ($sel.ServerArg) { $sel.ServerArg } else { $sel.ServerName }
        Write-Host ''
        Write-Host "Selecting: [$($sel.ServerName)] $($sel.AccountID)  ($($sel.Contact))" -ForegroundColor Cyan

        Invoke-PAAction -Description "Activate server '$($sel.ServerName)'" `
            -DryRunCommand "Set-PAServer '$srvArg'" `
            -Action { Set-PAServer $srvArg }

        Invoke-PAAction -Description "Activate account '$($sel.AccountID)'" `
            -DryRunCommand "Set-PAAccount -ID '$($sel.AccountID)'" `
            -Action { Set-PAAccount -ID $sel.AccountID }

        if ($script:DryRun) {
            Write-Host ''
            Write-Warn 'DRY-RUN: no context change applied.'
        } else {
            $script:Config.ACMEServer = $sel.ServerName
            Save-TUACMEConfig
            Write-Ok "Active: server=$($sel.ServerName)  account=$($sel.AccountID)"
            if ($sel.NeedsAltEncryption) {
                Write-Warn 'This account stores secure plugin args without portable encryption.'
                Write-Warn "Run 'a $key' to enable it before relying on unattended (SYSTEM) renewal."
            }
        }
        Wait-UI
        return
    }

    Write-Warn 'Unknown choice.'
    Wait-UI
}

function Enable-PAAccountAltEncryption {
    <#
        .SYNOPSIS
            Switches an account to portable AES plugin encryption so secure plugin
            args decrypt under any identity (e.g. the SYSTEM scheduled task).
    #>
    param([Parameter(Mandatory)][object]$Account)
    $srvArg = if ($Account.ServerArg) { $Account.ServerArg } else { $Account.ServerName }
    Write-Host ''
    Write-Host "Enabling portable encryption for [$($Account.ServerName)] $($Account.AccountID)" -ForegroundColor Cyan

    Invoke-PAAction -Description "Activate server '$($Account.ServerName)'" `
        -DryRunCommand "Set-PAServer '$srvArg'" `
        -Action { Set-PAServer $srvArg }

    Invoke-PAAction -Description "Activate account '$($Account.AccountID)'" `
        -DryRunCommand "Set-PAAccount -ID '$($Account.AccountID)'" `
        -Action { Set-PAAccount -ID $Account.AccountID }

    Invoke-PAAction -Description 'Enable portable (AES) plugin encryption' `
        -DryRunCommand 'Set-PAAccount -UseAltPluginEncryption' `
        -Action { Set-PAAccount -UseAltPluginEncryption }

    if (-not $script:DryRun) { Write-Ok 'Portable plugin encryption enabled.' }
}

function Invoke-CreateNewAccount {
    Write-Host ''
    Write-Step 'Create a new ACME account'

    $srvList = @()
    try { $srvList = Get-PAServer -List -ErrorAction Stop } catch { }
    if (-not $srvList) {
        Write-Warn 'No ACME servers are configured yet.'
        Write-Host '  Built-in aliases you can use: LE_PROD, LE_STAGE'
        Write-Host '  Or enter a full directory URL.'
    } else {
        Write-Host 'Known servers:' -ForegroundColor Cyan
        $i = 0
        foreach ($s in $srvList) {
            $i++
            Write-Host ("  {0,2}: {1}  ({2})" -f $i, $s.Name, $s.location)
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
    $parts = $srvLine.Trim() -split '\s+', 2
    $sCmd  = $parts[0].ToLower()
    $sArg  = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }

    $srvName = ''
    switch ($sCmd) {
        'c' { return }
        'p' { $srvName = 'LE_PROD' }
        't' { $srvName = 'LE_STAGE' }
        'u' {
            if (-not $sArg) { Write-Warn 'Provide a directory URL.'; Wait-UI; return }
            $srvName = $sArg
        }
        default {
            if ($sCmd -match '^\d+$' -and $srvList) {
                $idx = [int]$sCmd - 1
                if ($idx -ge 0 -and $idx -lt $srvList.Count) { $srvName = $srvList[$idx].Name }
                else { Write-Warn 'Number out of range.'; Wait-UI; return }
            } else {
                Write-Warn "Unknown input '$srvLine'."; Wait-UI; return
            }
        }
    }

    Write-Host ''
    Write-Host "Server: $srvName" -ForegroundColor Cyan
    $email = Read-Host 'Contact email (e.g. admin@contoso.com)'
    if (-not $email -or $email -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
        Write-Warn 'Invalid email. Aborting.'
        Wait-UI
        return
    }

    $srvArg = Resolve-PAServerArg $srvName
    if (-not (Confirm-Prompt "Create account on '$srvName'$(if ($srvArg -ne $srvName) { " (via $srvArg)" }) with contact '$email'?")) { return }

    Invoke-PAAction -Description "Set ACME server to '$srvName'" `
        -DryRunCommand "Set-PAServer $srvArg" `
        -Action { Set-PAServer $srvArg }

    Invoke-PAAction -Description 'Create new ACME account' `
        -DryRunCommand "New-PAAccount -Contact '$email' -AcceptTOS" `
        -Action { New-PAAccount -Contact $email -AcceptTOS }

    if ($script:DryRun) {
        Write-Host ''
        Write-Warn 'DRY-RUN: no account was created.'
    } else {
        $script:Config.ACMEServer   = $srvName
        $script:Config.ContactEmail = $email
        Save-TUACMEConfig
        $newAcct = $null
        try { $newAcct = Get-PAAccount -ErrorAction SilentlyContinue } catch { }
        if ($newAcct) {
            Write-Ok "Account created. id=$($newAcct.id)  contact=$email  server=$srvName"
        } else {
            Write-Ok 'Account creation submitted. Verify output above.'
        }
    }
    Wait-UI
}
