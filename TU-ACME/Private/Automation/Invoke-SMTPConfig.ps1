function Invoke-SMTPConfig {
    <#
    .SYNOPSIS
        SMTP configuration and test-mail entry point.
    .DESCRIPTION
        Presents a Show-Menu with two actions: configure the Email block
        on the TU-ACME config (host, port, SSL, optional auth credentials
        with a DPAPI-encrypted password persisted to smtp-credentials.xml),
        and send a test mail via Send-TUACMEMail. On a successful test
        mail this function writes Event 1007 to the TU-ACME event log.
    #>
    [CmdletBinding()]
    param()

    $title   = 'SMTP'
    $options = @(
        '1. Configure SMTP settings',
        '2. Send test mail',
        'B. Back'
    )

    while ($true) {
        $sel = Show-Menu -Title $title -Options $options
        switch ($sel) {
            0       { Invoke-SMTPConfigure }
            1       { Invoke-SMTPSendTest }
            2       { return }
            -1      { return }
            default { return }
        }
    }
}

function Invoke-SMTPConfigure {
    <#
    .SYNOPSIS
        Prompt for SMTP settings and persist them via Set-TUACMEConfig.
    #>
    [CmdletBinding()]
    param()

    Write-Host ''
    Write-Host '  === SMTP configuration ===' -ForegroundColor Cyan
    Write-Host ''

    $cfg     = Get-TUACMEConfig
    $current = $cfg.Email

    function Format-OrNotSet([object] $value) {
        if ($null -eq $value) { return '<not set>' }
        if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) {
            return '<not set>'
        }
        return $value.ToString()
    }

    Write-Host '  Current settings:' -ForegroundColor Cyan
    Write-Host ('    SmtpServer       : ' + (Format-OrNotSet $current.SmtpServer))
    Write-Host ('    SmtpPort         : ' + (Format-OrNotSet $current.SmtpPort))
    Write-Host ('    UseSsl           : ' + $current.UseSsl)
    Write-Host ('    UseAuth          : ' + $current.UseAuth)
    Write-Host ('    SenderAddress    : ' + (Format-OrNotSet $current.SenderAddress))
    Write-Host ('    RecipientAddress : ' + (Format-OrNotSet $current.RecipientAddress))
    Write-Host ''

    # ---- SmtpServer (required) -------------------------------------------
    $smtpServer = ''
    while ($true) {
        $smtpServer = Read-Host 'SMTP server'
        if (-not [string]::IsNullOrWhiteSpace($smtpServer)) { break }
        Write-Host '  SMTP server is required.' -ForegroundColor Yellow
    }

    # ---- SmtpPort (default 587) ------------------------------------------
    $portRaw = Read-Host 'SMTP port [587]'
    if ([string]::IsNullOrWhiteSpace($portRaw)) {
        $smtpPort = 587
    } else {
        $smtpPort = [int]$portRaw
    }

    # ---- UseSsl (default Y) ----------------------------------------------
    $sslRaw = Read-Host 'Use SSL? (Y/n)'
    $useSsl = -not ($sslRaw -match '^[nN]$')

    # ---- UseAuth (default Y) ---------------------------------------------
    $authRaw = Read-Host 'Use authentication? (Y/n)'
    $useAuth = -not ($authRaw -match '^[nN]$')

    # ---- SenderAddress ---------------------------------------------------
    $emailRegex = '^[^@\s]+@[^@\s]+\.[^@\s]+$'
    $sender = ''
    while ($true) {
        $sender = Read-Host 'Sender address'
        if ($sender -match $emailRegex) { break }
        Write-Host '  Invalid email address.' -ForegroundColor Yellow
    }

    # ---- RecipientAddress ------------------------------------------------
    $recipient = ''
    while ($true) {
        $recipient = Read-Host 'Recipient address'
        if ($recipient -match $emailRegex) { break }
        Write-Host '  Invalid email address.' -ForegroundColor Yellow
    }

    # ---- Optional auth credentials ---------------------------------------
    $username = $null
    $password = $null
    if ($useAuth) {
        $username = Read-Host 'SMTP username'
        $password = Read-Host -Prompt 'SMTP password' -AsSecureString
    }

    # ---- Summary + confirm -----------------------------------------------
    Write-Host ''
    Write-Host '  Summary:' -ForegroundColor Cyan
    Write-Host "    SmtpServer       : $smtpServer"
    Write-Host "    SmtpPort         : $smtpPort"
    Write-Host "    UseSsl           : $useSsl"
    Write-Host "    UseAuth          : $useAuth"
    Write-Host "    SenderAddress    : $sender"
    Write-Host "    RecipientAddress : $recipient"
    if ($useAuth) {
        Write-Host "    Username         : $username"
        Write-Host '    Password         : (set)'
    }
    Write-Host ''

    $confirm = Read-Host 'Save these settings? (y/N)'
    if ($confirm -notmatch '^[yY]$') {
        Write-Host '  Cancelled.' -ForegroundColor Yellow
        return
    }

    # ---- Persist the password DPAPI-encrypted ----------------------------
    if ($useAuth -and $null -ne $password) {
        $encPwd  = $password | ConvertFrom-SecureString
        $credObj = [PSCustomObject]@{
            Username    = $username
            PasswordEnc = $encPwd
        }
        $credDir  = Join-Path $env:ProgramData 'TU-ACME'
        if (-not (Test-Path $credDir)) {
            New-Item -ItemType Directory -Path $credDir -Force | Out-Null
        }
        $credPath = Join-Path $credDir 'smtp-credentials.xml'
        $credObj | Export-Clixml -Path $credPath
    }

    # ---- Persist the Email block via Set-TUACMEConfig --------------------
    $cfg.Email = [PSCustomObject]@{
        SmtpServer       = $smtpServer
        SmtpPort         = $smtpPort
        UseSsl           = $useSsl
        UseAuth          = $useAuth
        SenderAddress    = $sender
        RecipientAddress = $recipient
    }
    Set-TUACMEConfig -Config $cfg

    Write-Host '  Saved.' -ForegroundColor Green
    Read-Host 'Press Enter to continue' | Out-Null
}

function Invoke-SMTPSendTest {
    <#
    .SYNOPSIS
        Send a test mail via Send-TUACMEMail, emit Event 1007 on success.
    #>
    [CmdletBinding()]
    param()

    $body = "Test mail from TU-ACME v0.3.2 at $(Get-Date -Format 's')"

    try {
        $result = Send-TUACMEMail -Subject 'TU-ACME test mail' -Body $body
        if ($result -eq $false) {
            Write-Host '  Test mail failed.' -ForegroundColor Yellow
        } else {
            Write-Host '  Test mail sent.' -ForegroundColor Green
            Write-EventLogEntry -EventId 1007 -EntryType Information `
                -Message 'TU-ACME SMTP test mail sent.'
        }
    } catch {
        Write-Host "  Test mail failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    Read-Host 'Press Enter to continue' | Out-Null
}
