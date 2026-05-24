function Send-TUACMEMail {
    param(
        [Parameter(Mandatory)] [string] $Subject,
        [Parameter(Mandatory)] [string] $Body
    )

    $config      = Get-TUACMEConfig
    $email       = $config.Email
    $credPath    = Join-Path $env:ProgramData 'TU-ACME\smtp-credentials.xml'

    $mailParams = @{
        SmtpServer = $email.SmtpServer
        Port       = $email.SmtpPort
        From       = $email.SenderAddress
        To         = $email.RecipientAddress
        Subject    = $Subject
        Body       = $Body
        UseSsl     = $email.UseSsl
    }

    if ($email.UseAuth -and (Test-Path $credPath)) {
        try {
            $stored = Import-Clixml -Path $credPath
            $cred   = New-Object System.Management.Automation.PSCredential(
                $stored.Username,
                $stored.Password
            )
            $mailParams['Credential'] = $cred
        } catch {
            return $false
        }
    }

    try {
        Send-MailMessage @mailParams -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}
