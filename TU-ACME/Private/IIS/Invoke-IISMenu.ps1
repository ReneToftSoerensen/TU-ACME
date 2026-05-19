function Invoke-IISMenu {
    if (-not $script:TUACMEIsAdmin) {
        Show-StatusBar -AdminWarning 'IIS Integration kræver administratorrettigheder'
        Start-Sleep -Seconds 2
        return
    }

    # Tjek WebAdministration er tilgængeligt
    try {
        Import-Module WebAdministration -ErrorAction Stop
    } catch {
        Write-Host ''
        Write-Host '  [FEJL] WebAdministration-modulet er ikke tilgængeligt.' -ForegroundColor Red
        Write-Host '  IIS er muligvis ikke installeret på dette system.' -ForegroundColor Yellow
        Write-Host ''
        Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
        Invoke-ConsoleWaitKey
        return
    }

    while ($true) {
        $options = @(
            '1. Vis HTTPS-bindings',
            '2. Kobl certifikat til IIS-binding',
            '3. Opsæt automatisk IIS-opdatering ved fornyelse',
            'B. Tilbage'
        )
        $sel = Show-Menu -Title 'IIS Integration' -Options $options

        switch ($sel) {
            -1 { return }
            0  { _Show-IISBindings }
            1  { _Bind-CertToIIS }
            2  { _Register-PostRenewalPlugin }
            3  { return }
        }
    }
}

function _Show-IISBindings {
    Invoke-ConsoleClear
    Write-Host '  === HTTPS Bindings ===' -ForegroundColor Cyan
    Write-Host ''

    $bindings = @(Get-WebBinding -Protocol 'https' -ErrorAction SilentlyContinue)

    if ($bindings.Count -eq 0) {
        Write-Host '  Ingen HTTPS-bindings fundet.' -ForegroundColor Yellow
        Write-Host ''
        Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
        Invoke-ConsoleWaitKey
        return
    }

    # Hent Posh-ACME certifikat thumbprints til sammenligning
    $paCerts = @{}
    try {
        Get-PACertificate -List 2>$null | ForEach-Object {
            if ($_.Thumbprint) { $paCerts[$_.Thumbprint.ToUpper()] = $_.MainDomain }
        }
    } catch {}

    $rows = $bindings | ForEach-Object {
        $tp     = if ($_.certificateHash) { $_.certificateHash.ToUpper() } else { '' }
        $match  = if ($paCerts.ContainsKey($tp)) { $paCerts[$tp] } else { '—' }
        [PSCustomObject]@{
            Site       = $_.ItemXPath -replace ".*\[@name='(.+?)'\].*", '$1'
            Binding    = $_.bindingInformation
            Thumbprint = if ($tp.Length -gt 16) { $tp.Substring(0, 16) + '...' } else { $tp }
            PoshACME   = $match
        }
    }

    $colorRule = {
        param($row)
        if ($row.PoshACME -ne '—') { 'Green' } else { 'White' }
    }

    Show-Table -Data $rows `
        -Columns @('Site', 'Binding', 'Thumbprint', 'PoshACME') `
        -Headers @('Site', 'Binding', 'Thumbprint', 'Posh-ACME match') `
        -Widths  @(20, 25, 20, 20) `
        -ColorRule $colorRule

    Write-Host ''
    Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
    Invoke-ConsoleWaitKey
}

function _Bind-CertToIIS {
    # Vaelg certifikat fra Posh-ACME
    $certs = @(Get-PACertificate -List 2>$null)
    if ($certs.Count -eq 0) {
        Write-Host '  Ingen Posh-ACME certifikater fundet.' -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        return
    }

    $certOptions = $certs | ForEach-Object { $_.MainDomain }
    $certSel     = Show-Menu -Title 'Vaelg certifikat' -Options $certOptions
    if ($certSel -lt 0) { return }
    $cert = $certs[$certSel]

    # Vaelg bindings (multi-select med mellemrum)
    $bindings = @(Get-WebBinding -Protocol 'https' -ErrorAction SilentlyContinue)
    if ($bindings.Count -eq 0) {
        Write-Host '  Ingen HTTPS-bindings fundet.' -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        return
    }

    Invoke-ConsoleClear
    Write-Host '  === Vaelg bindings (Mellemrum = toggle, Enter = bekraeft) ===' -ForegroundColor Cyan
    Write-Host ''

    $selected = @($false) * $bindings.Count
    $index    = 0

    function Render-BindingList {
        Set-ConsoleCursorPos -X 0 -Y 2
        for ($i = 0; $i -lt $bindings.Count; $i++) {
            $check  = if ($selected[$i]) { '[X]' } else { '[ ]' }
            $site   = $bindings[$i].ItemXPath -replace ".*\[@name='(.+?)'\].*", '$1'
            $bind   = $bindings[$i].bindingInformation
            $line   = "  $check  $site  $bind"
            if ($i -eq $index) {
                Write-Host $line.PadRight(79) -ForegroundColor Black -BackgroundColor Cyan
            } else {
                Write-Host $line.PadRight(79) -ForegroundColor White
            }
        }
    }

    Render-BindingList
    try { [Console]::CursorVisible = $false } catch {}

    while ($true) {
        $key = Invoke-ConsoleReadKey
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow)   { if ($index -gt 0) { $index-- }; Render-BindingList }
            ([ConsoleKey]::DownArrow) { if ($index -lt $bindings.Count - 1) { $index++ }; Render-BindingList }
            ([ConsoleKey]::Spacebar)  { $selected[$index] = -not $selected[$index]; Render-BindingList }
            ([ConsoleKey]::Escape)    { try { [Console]::CursorVisible = $true } catch {}; return }
            ([ConsoleKey]::Enter)     { break }
        }
        if ($key.Key -eq [ConsoleKey]::Enter) { break }
    }

    try { [Console]::CursorVisible = $true } catch {}

    $toUpdate = 0..($bindings.Count - 1) | Where-Object { $selected[$_] }
    if ($toUpdate.Count -eq 0) {
        Write-Host '  Ingen bindings valgt. Afbryder.' -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        return
    }

    # Importer certifikat til Windows Store
    try {
        Import-PfxCertificate -FilePath $cert.PfxFile `
            -CertStoreLocation 'Cert:\LocalMachine\My' -Exportable | Out-Null
    } catch {
        Write-Host "  Advarsel: Kunne ikke importere til certifikatarkiv: $_" -ForegroundColor Yellow
    }

    # Opdater bindings
    foreach ($i in $toUpdate) {
        $b    = $bindings[$i]
        $site = $b.ItemXPath -replace ".*\[@name='(.+?)'\].*", '$1'
        try {
            $b.certificateHash = $cert.Thumbprint
            $b | Set-WebBinding
            Write-Host "  Opdateret: $site $($b.bindingInformation)" -ForegroundColor Green
            Write-EventLogEntry -EventId 1002 -Message "IIS-binding opdateret: $site — nyt thumbprint: $($cert.Thumbprint)"
        } catch {
            Write-Host "  Fejl ved opdatering af $site : $_" -ForegroundColor Red
            Write-EventLogEntry -EventId 3002 -Message "IIS-binding fejl: $site — $_" -EntryType Error
        }
    }

    Write-Host ''
    Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
    Invoke-ConsoleWaitKey
}

function _Register-PostRenewalPlugin {
    $scriptPath = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules\TU-ACME\Scripts\Posh-ACME-IIS-Plugin.ps1"

    Invoke-ConsoleClear
    Write-Host '  === Opsæt automatisk IIS-opdatering ===' -ForegroundColor Cyan
    Write-Host ''

    if (-not (Test-Path $scriptPath)) {
        Write-Host "  Scriptfil ikke fundet: $scriptPath" -ForegroundColor Red
        Write-Host '  Placer Posh-ACME-IIS-Plugin.ps1 i TU-ACME\Scripts\ og prøv igen.' -ForegroundColor Yellow
        Write-Host ''
        Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
        Invoke-ConsoleWaitKey
        return
    }

    $current = (Get-PAServer 2>$null | Select-Object -ExpandProperty PostScript) 2>$null
    if ($current) {
        Write-Host "  Nuværende PostScript: $current" -ForegroundColor DarkGray
        Write-Host ''
    }

    Write-Host "  Script: $scriptPath"
    Write-Host ''
    $confirm = Read-Host '  Registrer dette script som post-renewal plugin? (J/N)'
    if ($confirm -notmatch '^[Jj]') { return }

    try {
        Set-PAConfig -PostScript $scriptPath
        Write-Host '  Post-renewal plugin registreret.' -ForegroundColor Green
        Write-Host '  IIS-bindings opdateres automatisk ved næste certifikatfornyelse.' -ForegroundColor White
    } catch {
        Write-Host "  Fejl: $_" -ForegroundColor Red
    }

    Write-Host ''
    Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
    Invoke-ConsoleWaitKey
}
