function Invoke-SMTPConfig {
    Invoke-ConsoleClear
    Write-Host '  === Konfigurer SMTP-fejladvisering ===' -ForegroundColor Cyan
    Write-Host ''

    $config = Get-TUACMEConfig
    $email  = $config.Email

    # Indsaml SMTP-indstillinger
    $server = Read-Host "  SMTP-server (nuværende: $($email.SmtpServer))"
    if ($server -ne '') { $email.SmtpServer = $server }

    $portStr = Read-Host "  Port (nuværende: $($email.SmtpPort))"
    if ($portStr -ne '') { $email.SmtpPort = [int]$portStr }

    $sslStr = Read-Host "  Brug SSL? (J/N, nuværende: $(if ($email.UseSsl) { 'J' } else { 'N' }))"
    if ($sslStr -match '^[JjYy]') { $email.UseSsl = $true }
    elseif ($sslStr -match '^[Nn]') { $email.UseSsl = $false }

    $sender = Read-Host "  Afsenderadresse (nuværende: $($email.SenderAddress))"
    if ($sender -ne '') { $email.SenderAddress = $sender }

    $recipient = Read-Host "  Modtageradresse (nuværende: $($email.RecipientAddress))"
    if ($recipient -ne '') { $email.RecipientAddress = $recipient }

    $authStr = Read-Host "  Brug godkendelse? (J/N, nuværende: $(if ($email.UseAuth) { 'J' } else { 'N' }))"
    if ($authStr -match '^[JjYy]') { $email.UseAuth = $true }
    elseif ($authStr -match '^[Nn]') { $email.UseAuth = $false }

    if ($email.UseAuth) {
        Write-Host ''
        $smtpUser = Read-Host '  SMTP brugernavn'
        $smtpPass = ConvertTo-MaskedInput -Prompt '  SMTP adgangskode' -AsSecureString
        if ($smtpPass -ne $null -and $smtpUser -ne '') {
            $credPath = Join-Path $env:ProgramData 'TU-ACME\smtp-credentials.xml'
            [PSCustomObject]@{
                Username = $smtpUser
                Password = $smtpPass
            } | Export-Clixml -Path $credPath
            Write-Host '  Credentials gemt (DPAPI-krypteret).' -ForegroundColor Green
            Write-Host '  Bemærk: Credentials er bundet til denne bruger og maskine.' -ForegroundColor DarkGray
        }
    }

    $config.Email = $email
    Set-TUACMEConfig -Config $config
    Write-Host '  SMTP-konfiguration gemt.' -ForegroundColor Green

    Write-Host ''
    $sendTest = Read-Host '  Send test-mail nu? (J/N)'
    if ($sendTest -match '^[JjYy]') {
        _Send-TestMail
    }
}

function _Send-TestMail {
    $subject = '[TU-ACME] Test-mail'
    $body    = @"
Dette er en test-mail fra TU-ACME.

Tidsstempel: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Server:      $env:COMPUTERNAME
Version:     0.0.2

-- Sendt automatisk af TU-ACME --
"@

    Write-Host '  Sender test-mail ...' -ForegroundColor Cyan

    $success = Send-TUACMEMail -Subject $subject -Body $body

    if ($success) {
        $config = Get-TUACMEConfig
        Write-Host "  Test-mail sendt til $($config.Email.RecipientAddress)." -ForegroundColor Green
    } else {
        Write-Host '  Fejl ved afsendelse af test-mail.' -ForegroundColor Red
        Write-Host '  Kontrollér SMTP-indstillinger og prøv igen.' -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
    Invoke-ConsoleWaitKey
}
