function Get-TUACMEConfig {
    $configPath = Join-Path $env:ProgramData 'TU-ACME\config.json'

    $defaults = [PSCustomObject]@{
        Version       = '1.0'
        ScheduledTask = [PSCustomObject]@{
            TaskName     = 'Posh-ACME-AutoRenewal'
            RunTime      = '03:00'
            RunAsAccount = 'SYSTEM'
        }
        Email         = [PSCustomObject]@{
            SmtpServer       = ''
            SmtpPort         = 587
            UseSsl           = $true
            UseAuth          = $true
            SenderAddress    = ''
            RecipientAddress = ''
        }
        Dashboard     = [PSCustomObject]@{
            WarnDaysThreshold = 30
            DefaultSort       = 'ExpiryAscending'
        }
        DNS           = [PSCustomObject]@{
            DefaultDnsSleep         = 120
            DefaultValidationTimeout = 60
            PersistentRecords       = $false
        }
    }

    if (-not (Test-Path $configPath)) {
        return $defaults
    }

    try {
        $json = Get-Content -Path $configPath -Raw -Encoding UTF8
        return $json | ConvertFrom-Json
    } catch {
        return $defaults
    }
}
