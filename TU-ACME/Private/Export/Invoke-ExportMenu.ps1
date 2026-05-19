function Invoke-ExportMenu {
    param($Cert = $null)

    # If no certificate is passed in, let the user select one from the dashboard
    if ($Cert -eq $null) {
        $certs = @(Get-PACertificate -List 2>$null)
        if ($certs.Count -eq 0) {
            Write-Host '  No certificates found.' -ForegroundColor Yellow
            Start-Sleep -Seconds 1
            return
        }
        $options = $certs | ForEach-Object { $_.MainDomain }
        $sel     = Show-Menu -Title 'Select certificate to export' -Options $options
        if ($sel -lt 0) { return }
        $Cert = $certs[$sel]
    }

    while ($true) {
        $options = @(
            '1. Export as PFX',
            '2. Export as PEM/CRT/KEY',
            '3. Import to Windows Certificate Store',
            'B. Back'
        )
        $sel = Show-Menu -Title "Export: $($Cert.MainDomain)" -Options $options

        switch ($sel) {
            -1 { return }
            0  { _Export-PFX -Cert $Cert }
            1  { _Export-PEM -Cert $Cert }
            2  { _Import-WinStore -Cert $Cert }
            3  { return }
        }
    }
}

function _Export-PFX {
    param($Cert)

    Invoke-ConsoleClear
    Write-Host '  === Eksporter PFX ===' -ForegroundColor Cyan
    Write-Host ''

    $desktop = [System.Environment]::GetFolderPath('Desktop')
    if (-not $desktop) { $desktop = [System.IO.Path]::GetTempPath() }
    $defaultPath = Join-Path $desktop "$($Cert.MainDomain).pfx"
    Write-Host "  Destinationssti (standard: $defaultPath):" -ForegroundColor Gray
    $path = Read-Host '  Sti'
    if ($path -eq '') { $path = $defaultPath }

    $pass1 = ConvertTo-MaskedInput -Prompt '  PFX adgangskode' -AsSecureString
    if ($pass1 -eq $null) { return }
    $pass2 = ConvertTo-MaskedInput -Prompt '  Bekraeft adgangskode' -AsSecureString
    if ($pass2 -eq $null) { return }

    # Sammenlign SecureString
    $p1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass1))
    $p2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass2))

    if ($p1 -ne $p2) {
        Write-Host '  Adgangskoderne er ikke ens. Prøv igen.' -ForegroundColor Red
        Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
        Invoke-ConsoleWaitKey
        return
    }

    try {
        $pfxBytes = [System.IO.File]::ReadAllBytes($Cert.PfxFile)
        $cert509  = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
            $pfxBytes, [string]::Empty,
            [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
        )
        $exported = $cert509.Export(
            [System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx,
            $p1
        )
        [System.IO.File]::WriteAllBytes($path, $exported)
        Write-Host "  PFX gemt: $path" -ForegroundColor Green
    } catch {
        Write-Host "  Fejl ved eksport: $_" -ForegroundColor Red
        if ($_ -match 'Access') {
            Write-Host '  Kontrollér at du har skriverettigheder til destinationsmappen.' -ForegroundColor Yellow
        }
    }

    Write-Host ''
    Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
    Invoke-ConsoleWaitKey
}

function _Export-PEM {
    param($Cert)

    Invoke-ConsoleClear
    Write-Host '  === Eksporter PEM/CRT/KEY ===' -ForegroundColor Cyan
    Write-Host ''

    $defaultDir = [System.Environment]::GetFolderPath('Desktop')
    if (-not $defaultDir) { $defaultDir = [System.IO.Path]::GetTempPath() }
    Write-Host "  Destinationsmappe (standard: $defaultDir):" -ForegroundColor Gray
    $dir = Read-Host '  Mappe'
    if ($dir -eq '') { $dir = $defaultDir }

    if (-not (Test-Path $dir)) {
        $create = Read-Host "  Mappen '$dir' eksisterer ikke. Opret? (J/N)"
        if ($create -match '^[Jj]') {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        } else {
            return
        }
    }

    try {
        $domain  = $Cert.MainDomain -replace '[^a-zA-Z0-9\.\-]', '_'
        $certDst = Join-Path $dir "$domain.crt"
        $keyDst  = Join-Path $dir "$domain.key"
        $chainDst= Join-Path $dir "$domain.chain.crt"

        Copy-Item -Path $Cert.CertFile  -Destination $certDst  -Force
        Copy-Item -Path $Cert.KeyFile   -Destination $keyDst   -Force
        Copy-Item -Path $Cert.ChainFile -Destination $chainDst -Force

        Write-Host '  Eksporterede filer:' -ForegroundColor Green
        Write-Host "    Certifikat: $certDst"  -ForegroundColor White
        Write-Host "    Privat nøgle: $keyDst" -ForegroundColor White
        Write-Host "    Certifikatkæde: $chainDst" -ForegroundColor White
    } catch {
        Write-Host "  Fejl ved eksport: $_" -ForegroundColor Red
        if ($_ -match 'Access') {
            Write-Host '  Kontrollér skriverettigheder.' -ForegroundColor Yellow
        }
    }

    Write-Host ''
    Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
    Invoke-ConsoleWaitKey
}

function _Import-WinStore {
    param($Cert)

    if (-not $script:TUACMEIsAdmin) {
        Show-StatusBar -AdminWarning 'Import til Windows Store kræver administratorrettigheder'
        Start-Sleep -Seconds 2
        return
    }

    Invoke-ConsoleClear
    Write-Host '  === Importer til Windows Certificate Store ===' -ForegroundColor Cyan
    Write-Host ''

    $storeOptions = @(
        '1. Personligt (My)',
        '2. Web Hosting (WebHosting)'
    )
    $storeSel = Show-Menu -Title 'Vaelg certifikatarkiv' -Options $storeOptions
    if ($storeSel -lt 0) { return }

    $storeName = if ($storeSel -eq 0) { 'My' } else { 'WebHosting' }

    try {
        Import-PfxCertificate -FilePath $Cert.PfxFile `
            -CertStoreLocation "Cert:\LocalMachine\$storeName" `
            -Exportable | Out-Null
        Write-Host "  Certifikat importeret til LocalMachine\$storeName." -ForegroundColor Green
    } catch {
        Write-Host "  Fejl ved import: $_" -ForegroundColor Red
    }

    Write-Host ''
    Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
    Invoke-ConsoleWaitKey
}
