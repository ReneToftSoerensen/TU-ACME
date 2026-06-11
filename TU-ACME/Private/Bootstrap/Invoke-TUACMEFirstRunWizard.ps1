function Invoke-TUACMEFirstRunWizard {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    Write-Host 'TU-ACME first-run setup' -ForegroundColor Cyan
    Write-Host 'Configuring the production and staging ACME accounts.' -ForegroundColor DarkCyan

    $contactEmail = ''
    while ($contactEmail -notmatch '@') {
        $contactEmail = Read-Host 'Contact email for ACME accounts'
    }

    $prodUrl = ''
    while ($prodUrl -notlike 'https://*') {
        $prodUrl = Read-Host 'Production ACME directory URL'
    }

    $stagingUrl = ''
    while ($stagingUrl -notlike 'https://*') {
        $stagingUrl = Read-Host 'Staging ACME directory URL'
    }

    $config = [pscustomobject]@{
        ContactEmail        = $contactEmail
        ProdDirectoryUrl    = $prodUrl
        ProdAccountId       = ''
        StagingDirectoryUrl = $stagingUrl
        StagingAccountId    = ''
    }
    Save-TUACMEConfig -Config $config

    $null = Use-TUACMEProdAccount
    $prodAccount = New-PAAccount -Contact $contactEmail -AcceptTOS -ErrorAction Stop
    if ($null -eq $prodAccount -or [string]::IsNullOrEmpty([string]$prodAccount.id)) {
        throw 'New-PAAccount did not return a production account id.'
    }
    $config.ProdAccountId = [string]$prodAccount.id

    $null = Use-TUACMEStagingAccount
    $stagingAccount = New-PAAccount -Contact $contactEmail -AcceptTOS -ErrorAction Stop
    if ($null -eq $stagingAccount -or [string]::IsNullOrEmpty([string]$stagingAccount.id)) {
        throw 'New-PAAccount did not return a staging account id.'
    }
    $config.StagingAccountId = [string]$stagingAccount.id

    Save-TUACMEConfig -Config $config

    # Prod is the default context; never leave the session pointed at staging.
    $null = Use-TUACMEProdAccount

    Write-TUACMEEventLog -EventId 1010 -EntryType Information -Message 'TU-ACME first-run initialization completed.'
    Write-Host 'TU-ACME first-run setup completed.' -ForegroundColor Cyan

    return $config
}
