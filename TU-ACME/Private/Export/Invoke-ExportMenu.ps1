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
    Write-Host '  === Export PFX ===' -ForegroundColor Cyan
    Write-Host ''

    $desktop = [System.Environment]::GetFolderPath('Desktop')
    if (-not $desktop) { $desktop = [System.IO.Path]::GetTempPath() }
    $defaultPath = Join-Path $desktop "$($Cert.MainDomain).pfx"
    Write-Host "  Destination path (default: $defaultPath):" -ForegroundColor Gray
    $path = Read-Host '  Path'
    if ($path -eq '') { $path = $defaultPath }

    $pass1 = ConvertTo-MaskedInput -Prompt '  PFX password' -AsSecureString
    if ($pass1 -eq $null) { return }
    $pass2 = ConvertTo-MaskedInput -Prompt '  Confirm password' -AsSecureString
    if ($pass2 -eq $null) { return }

    # Compare SecureString
    $p1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass1))
    $p2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass2))

    if ($p1 -ne $p2) {
        Write-Host '  Passwords do not match. Try again.' -ForegroundColor Red
        Write-Host '  Press any key...' -ForegroundColor DarkGray
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
        Write-Host "  PFX saved: $path" -ForegroundColor Green
    } catch {
        Write-Host "  Export error: $_" -ForegroundColor Red
        if ($_ -match 'Access') {
            Write-Host '  Check that you have write permissions to the destination folder.' -ForegroundColor Yellow
        }
    }

    Write-Host ''
    Write-Host '  Press any key...' -ForegroundColor DarkGray
    Invoke-ConsoleWaitKey
}

function _Export-PEM {
    param($Cert)

    Invoke-ConsoleClear
    Write-Host '  === Export PEM/CRT/KEY ===' -ForegroundColor Cyan
    Write-Host ''

    $defaultDir = [System.Environment]::GetFolderPath('Desktop')
    if (-not $defaultDir) { $defaultDir = [System.IO.Path]::GetTempPath() }
    Write-Host "  Destination folder (default: $defaultDir):" -ForegroundColor Gray
    $dir = Read-Host '  Folder'
    if ($dir -eq '') { $dir = $defaultDir }

    if (-not (Test-Path $dir)) {
        $create = Read-Host "  The folder '$dir' does not exist. Create? (Y/N)"
        if ($create -match '^[Yy]') {
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

        Write-Host '  Exported files:' -ForegroundColor Green
        Write-Host "    Certificate: $certDst"  -ForegroundColor White
        Write-Host "    Private key: $keyDst" -ForegroundColor White
        Write-Host "    Certificate chain: $chainDst" -ForegroundColor White
    } catch {
        Write-Host "  Export error: $_" -ForegroundColor Red
        if ($_ -match 'Access') {
            Write-Host '  Check write permissions.' -ForegroundColor Yellow
        }
    }

    Write-Host ''
    Write-Host '  Press any key...' -ForegroundColor DarkGray
    Invoke-ConsoleWaitKey
}

function _Import-WinStore {
    param($Cert)

    if (-not $script:TUACMEIsAdmin) {
        Show-StatusBar -AdminWarning 'Import to Windows Store requires administrator privileges'
        Start-Sleep -Seconds 2
        return
    }

    Invoke-ConsoleClear
    Write-Host '  === Import to Windows Certificate Store ===' -ForegroundColor Cyan
    Write-Host ''

    $storeOptions = @(
        '1. Personal (My)',
        '2. Web Hosting (WebHosting)'
    )
    $storeSel = Show-Menu -Title 'Select certificate store' -Options $storeOptions
    if ($storeSel -lt 0) { return }

    $storeName = if ($storeSel -eq 0) { 'My' } else { 'WebHosting' }

    try {
        Import-PfxCertificate -FilePath $Cert.PfxFile `
            -CertStoreLocation "Cert:\LocalMachine\$storeName" `
            -Exportable | Out-Null
        Write-Host "  Certificate imported to LocalMachine\$storeName." -ForegroundColor Green
    } catch {
        Write-Host "  Import error: $_" -ForegroundColor Red
    }

    Write-Host ''
    Write-Host '  Press any key...' -ForegroundColor DarkGray
    Invoke-ConsoleWaitKey
}
