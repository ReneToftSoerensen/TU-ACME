function Initialize-TUACMEEnvironment {
    <#
    .SYNOPSIS
        First-run wizard: prompts for prod URL, staging URL, contact email;
        creates one Posh-ACME account per environment; persists the IDs to
        config.json. Idempotent unless -Force.
    #>
    [CmdletBinding()]
    param([switch] $Force)

    $cfg = Get-TUACMEConfig

    if ($cfg.Acme.Initialized -eq $true -and -not $Force) {
        Write-Host "  TU-ACME already initialized. Use -Force to re-run the wizard." -ForegroundColor DarkGray
        return
    }

    Invoke-ConsoleClear
    Write-Host "  === TU-ACME first-run setup ===" -ForegroundColor Cyan
    Write-Host ""

    # Prompt + validate prod directory URL
    $prodUrl = ''
    while ($true) {
        $prodUrl = Read-Host "Prod ACME directory URL"
        if ($prodUrl -match '^https://') { break }
        Write-Host "  Must start with https://" -ForegroundColor Yellow
    }

    # Prompt + validate staging directory URL
    $stagingUrl = ''
    while ($true) {
        $stagingUrl = Read-Host "Staging ACME directory URL"
        if ($stagingUrl -match '^https://') { break }
        Write-Host "  Must start with https://" -ForegroundColor Yellow
    }

    # Prompt + validate contact email
    $email = ''
    while ($true) {
        $email = Read-Host "Contact email"
        if ($email -match '^[^@\s]+@[^@\s]+\.[^@\s]+$') { break }
        Write-Host "  Invalid email address" -ForegroundColor Yellow
    }

    # Summary + confirmation
    Write-Host ""
    Write-Host "  Summary:" -ForegroundColor Cyan
    Write-Host "    Prod directory    : $prodUrl"
    Write-Host "    Staging directory : $stagingUrl"
    Write-Host "    Contact email     : $email"
    Write-Host ""

    $confirm = Read-Host "Proceed? (y/N)"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "  Cancelled." -ForegroundColor Yellow
        return
    }

    # Create prod account
    $prodId = ''
    Show-Spinner -Message 'Registering prod account...' -ScriptBlock {
        Set-PAServer -DirectoryUrl $prodUrl
        # -Force suppresses Posh-ACME's "wish to duplicate?" prompt when an
        # account with matching contacts already exists. In v2 we always
        # create distinct prod + staging accounts even when both URLs point
        # at the same internal CA (the duplicate gets a different key and
        # account ID), so the prompt should never block the wizard.
        $acct = New-PAAccount -Contact $email -AcceptTOS -Force
        if ($null -eq $acct) {
            # Posh-ACME 4.32+ returns nothing on success; recover via Get-PAAccount.
            $acct = Get-PAAccount
        }
        $script:_tuacmeProdId = $acct.id
    }
    $prodId = $script:_tuacmeProdId

    # Create staging account
    $stagingId = ''
    Show-Spinner -Message 'Registering staging account...' -ScriptBlock {
        Set-PAServer -DirectoryUrl $stagingUrl
        # -Force suppresses Posh-ACME's "wish to duplicate?" prompt when an
        # account with matching contacts already exists. In v2 we always
        # create distinct prod + staging accounts even when both URLs point
        # at the same internal CA (the duplicate gets a different key and
        # account ID), so the prompt should never block the wizard.
        $acct = New-PAAccount -Contact $email -AcceptTOS -Force
        if ($null -eq $acct) {
            $acct = Get-PAAccount
        }
        $script:_tuacmeStagingId = $acct.id
    }
    $stagingId = $script:_tuacmeStagingId

    # Persist config
    $cfg.Acme.ProdDirectoryUrl    = $prodUrl
    $cfg.Acme.StagingDirectoryUrl = $stagingUrl
    $cfg.Acme.ContactEmail        = $email
    $cfg.Acme.ProdAccountId       = $prodId
    $cfg.Acme.StagingAccountId    = $stagingId
    $cfg.Acme.Initialized         = $true
    $cfg.Acme.InitializedAt       = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    Set-TUACMEConfig -Config $cfg

    Write-EventLogEntry -EventId 1010 -EntryType Information -Message "TU-ACME initialized (prod=$prodId, staging=$stagingId)"

    Write-Host ""
    Write-Host "  Setup complete." -ForegroundColor Green
    Read-Host "Press Enter to continue" | Out-Null
}
