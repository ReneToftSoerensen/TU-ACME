# Reusable fake objects for TU-ACME tests.

function global:New-FakeAccount {
    param(
        [string] $Id      = 'acc-001',
        [string] $Contact = 'mailto:admin@eksempel.dk',
        [string] $Status  = 'valid'
    )
    [PSCustomObject]@{ id = $Id; contact = $Contact; status = $Status }
}

function global:New-FakeCertificate {
    param(
        [string]   $Domain     = 'eksempel.dk',
        [int]      $DaysLeft   = 60,
        [string]   $Thumbprint = 'AABBCCDDEEFF00112233445566778899AABBCCDD'
    )
    $notAfter = (Get-Date).AddDays($DaysLeft)
    [PSCustomObject]@{
        MainDomain  = $Domain
        SANs        = @($Domain)
        Issuer      = "Let's Encrypt Authority X3"
        NotBefore   = (Get-Date).AddDays(-30)
        NotAfter    = $notAfter
        Thumbprint  = $Thumbprint
        KeyLength   = 2048
        Plugin      = 'Cloudflare'
        RenewAfter  = (Get-Date).AddDays($DaysLeft - 30)
        CertFile    = 'C:\PoshACME\eksempel.dk\cert.cer'
        KeyFile     = 'C:\PoshACME\eksempel.dk\cert.key'
        ChainFile   = 'C:\PoshACME\eksempel.dk\chain.cer'
        PfxFile     = 'C:\PoshACME\eksempel.dk\cert.pfx'
        status      = 'valid'
    }
}

function global:New-FakeExpiredCertificate {
    New-FakeCertificate -Domain 'expired.dk' -DaysLeft -5 -Thumbprint 'DEADBEEF00000000DEADBEEF00000000DEADBEEF'
}

function global:New-FakeWarnCertificate {
    New-FakeCertificate -Domain 'warn.dk' -DaysLeft 20 -Thumbprint '1111222233334444111122223333444411112222'
}

function global:New-FakeIISBinding {
    param(
        [string] $SiteName   = 'Default Web Site',
        [string] $Thumbprint = 'AABBCCDDEEFF00112233445566778899AABBCCDD',
        [string] $Binding    = '*:443:'
    )
    [PSCustomObject]@{
        ItemXPath          = "IIS:\Sites\$SiteName"
        bindingInformation = $Binding
        certificateHash    = $Thumbprint
        protocol           = 'https'
    }
}

function global:New-FakePlugin {
    param([string] $Name = 'Cloudflare')
    [PSCustomObject]@{ Plugin = $Name }
}

function global:New-FakePluginArgs {
    [PSCustomObject]@{
        CFToken = ''
    }
}

function global:New-FakeConfig {
    [PSCustomObject]@{
        Version       = '1.0'
        ScheduledTask = [PSCustomObject]@{ TaskName = 'Posh-ACME-AutoRenewal'; RunTime = '03:00'; RunAsAccount = 'SYSTEM' }
        Email         = [PSCustomObject]@{ SmtpServer = 'smtp.test.dk'; SmtpPort = 587; UseSsl = $true; UseAuth = $false; SenderAddress = 'from@test.dk'; RecipientAddress = 'to@test.dk' }
        Dashboard     = [PSCustomObject]@{ WarnDaysThreshold = 30; DefaultSort = 'ExpiryAscending' }
        DNS           = [PSCustomObject]@{ DefaultDnsSleep = 120; DefaultValidationTimeout = 60; PersistentRecords = $false }
    }
}

function global:New-FakeRenewalResult {
    param([string] $Domain = 'eksempel.dk')
    [PSCustomObject]@{ MainDomain = $Domain; Thumbprint = 'NEWTHUMPRINT1234'; NotAfter = (Get-Date).AddDays(90) }
}

function global:New-FakeScheduledTask {
    param([string] $Name = 'Posh-ACME-AutoRenewal', [string] $State = 'Ready')
    [PSCustomObject]@{ TaskName = $Name; State = $State }
}

function global:New-FakeAcmeDnsAccount {
    [PSCustomObject]@{
        username   = 'a0b1c2d3-0000-0000-0000-000000000001'
        password   = 'supersecretpassword1234567890abcdef'
        subdomain  = 'a0b1c2d3-0000-0000-0000-000000000001'
        fulldomain = 'a0b1c2d3-0000.auth.acme-dns.io'
        allowfrom  = @()
    }
}
