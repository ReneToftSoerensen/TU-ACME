function Invoke-SMTPConfig {
    Invoke-ConsoleClear
    Write-Host '  === Configure SMTP failure notification ===' -ForegroundColor Cyan
    Write-Host ''

    $config = Get-TUACMEConfig
    $email  = $config.Email

    # Collect SMTP settings
    $server = Read-Host "  SMTP server (current: $($email.SmtpServer))"
    if ($server -ne '') { $email.SmtpServer = $server }

    $portStr = Read-Host "  Port (current: $($email.SmtpPort))"
    if ($portStr -ne '') { $email.SmtpPort = [int]$portStr }

    $sslStr = Read-Host "  Use SSL? (Y/N, current: $(if ($email.UseSsl) { 'Y' } else { 'N' }))"
    if ($sslStr -match '^[Yy]') { $email.UseSsl = $true }
    elseif ($sslStr -match '^[Nn]') { $email.UseSsl = $false }

    $sender = Read-Host "  Sender address (current: $($email.SenderAddress))"
    if ($sender -ne '') { $email.SenderAddress = $sender }

    $recipient = Read-Host "  Recipient address (current: $($email.RecipientAddress))"
    if ($recipient -ne '') { $email.RecipientAddress = $recipient }

    $authStr = Read-Host "  Use authentication? (Y/N, current: $(if ($email.UseAuth) { 'Y' } else { 'N' }))"
    if ($authStr -match '^[Yy]') { $email.UseAuth = $true }
    elseif ($authStr -match '^[Nn]') { $email.UseAuth = $false }

    if ($email.UseAuth) {
        Write-Host ''
        $smtpUser = Read-Host '  SMTP username'
        $smtpPass = ConvertTo-MaskedInput -Prompt '  SMTP password' -AsSecureString
        if ($smtpPass -ne $null -and $smtpUser -ne '') {
            $credPath = Join-Path $env:ProgramData 'TU-ACME\smtp-credentials.xml'
            [PSCustomObject]@{
                Username = $smtpUser
                Password = $smtpPass
            } | Export-Clixml -Path $credPath
            Write-Host '  Credentials saved (DPAPI-encrypted).' -ForegroundColor Green
            Write-Host '  Note: Credentials are bound to this user and machine.' -ForegroundColor DarkGray
        }
    }

    $config.Email = $email
    Set-TUACMEConfig -Config $config
    Write-Host '  SMTP configuration saved.' -ForegroundColor Green

    Write-Host ''
    $sendTest = Read-Host '  Send test email now? (Y/N)'
    if ($sendTest -match '^[Yy]') {
        _Send-TestMail
    }
}

function _Send-TestMail {
    $subject = '[TU-ACME] Test email'
    $body    = @"
This is a test email from TU-ACME.

Timestamp:   $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Server:      $env:COMPUTERNAME
Version:     0.0.2

-- Sent automatically by TU-ACME --
"@

    Write-Host '  Sending test email ...' -ForegroundColor Cyan

    $success = Send-TUACMEMail -Subject $subject -Body $body

    if ($success) {
        $config = Get-TUACMEConfig
        Write-Host "  Test email sent to $($config.Email.RecipientAddress)." -ForegroundColor Green
    } else {
        Write-Host '  Error sending test email.' -ForegroundColor Red
        Write-Host '  Check SMTP settings and try again.' -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host '  Press any key...' -ForegroundColor DarkGray
    Invoke-ConsoleWaitKey
}
