function Invoke-TUACMEFirstRunWizard {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    Write-Host 'TU-ACME first-run setup' -ForegroundColor Cyan
    Write-Host 'Configuring the production and staging ACME accounts.' -ForegroundColor DarkCyan

    # Fail fast before prompting: account creation below needs the real
    # Posh-ACME commands available in this session.
    if (-not (Import-TUACMEPoshACME)) {
        throw 'Posh-ACME is required for first-run setup but could not be imported. Install it with: Install-Module Posh-ACME -Scope AllUsers'
    }

    # Input is trimmed before validation: stray whitespace would survive the
    # prefix checks but later break Set-PAServer / New-PAAccount.
    # Validation errors render in Cyan, not Write-Warning yellow (UC-4.03).
    $contactEmail = ''
    while ($contactEmail -notmatch '@') {
        if (-not [string]::IsNullOrEmpty($contactEmail)) {
            Write-Host 'The contact email must contain "@".' -ForegroundColor Cyan
        }
        $contactEmail = ([string](Read-Host 'Contact email for ACME accounts')).Trim()
    }

    $prodUrl = ''
    while ($prodUrl -notlike 'https://*') {
        if (-not [string]::IsNullOrEmpty($prodUrl)) {
            Write-Host 'The directory URL must start with https:// (forward slashes).' -ForegroundColor Cyan
        }
        $prodUrl = ([string](Read-Host 'Production ACME directory URL')).Trim()
    }

    $stagingUrl = ''
    while ($stagingUrl -notlike 'https://*') {
        if (-not [string]::IsNullOrEmpty($stagingUrl)) {
            Write-Host 'The directory URL must start with https:// (forward slashes).' -ForegroundColor Cyan
        }
        $stagingUrl = ([string](Read-Host 'Staging ACME directory URL')).Trim()
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
