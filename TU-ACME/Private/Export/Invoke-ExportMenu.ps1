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
        Wait-AnyKey
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
    Wait-AnyKey
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
        if (-not (Confirm-YesNo "  The folder '$dir' does not exist. Create? (Y/N)")) { return }
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
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
    Wait-AnyKey
}

function _Import-WinStore {
    param($Cert)

    if (-not $script:OnWindows) {
        Write-Host '  Windows certificate store is only available on Windows.' -ForegroundColor Yellow
        Wait-AnyKey
        return
    }

    Invoke-ConsoleClear
    Write-Host '  === Import to Windows Certificate Store ===' -ForegroundColor Cyan
    Write-Host ''

    # Scope selection. LocalMachine requires admin; CurrentUser is
    # always allowed. If we're not admin there's only one valid choice
    # so we skip the prompt entirely.
    $scope = 'CurrentUser'
    if ($script:TUACMEIsAdmin) {
        $scopeOptions = @(
            '1. Local computer (LocalMachine) — visible to all users and services',
            '2. Current user (CurrentUser)    — only the user running TU-ACME'
        )
        $scopeSel = Show-Menu -Title 'Where should the certificate be imported?' -Options $scopeOptions
        if ($scopeSel -lt 0) { return }
        $scope = if ($scopeSel -eq 0) { 'LocalMachine' } else { 'CurrentUser' }
    } else {
        Write-Host '  Not running as administrator — importing into CurrentUser store.' -ForegroundColor Yellow
        Write-Host '  Re-run TU-ACME elevated to install into LocalMachine.' -ForegroundColor DarkGray
        Write-Host ''
    }

    $storeOptions = @(
        '1. Personal (My)',
        '2. Web Hosting (WebHosting)'
    )
    $storeSel = Show-Menu -Title 'Select certificate store' -Options $storeOptions
    if ($storeSel -lt 0) { return }

    $storeName = if ($storeSel -eq 0) { 'My' } else { 'WebHosting' }
    $certLoc   = "Cert:\$scope\$storeName"

    if (-not $Cert.PfxFile -or -not (Test-Path $Cert.PfxFile)) {
        Write-Host "  PFX file not found at: $($Cert.PfxFile)" -ForegroundColor Red
        Write-Host '  The certificate may have been issued without a PFX bundle.' -ForegroundColor DarkGray
        Wait-AnyKey
        return
    }

    try {
        Import-PfxCertificate -FilePath $Cert.PfxFile `
            -CertStoreLocation $certLoc `
            -Exportable | Out-Null
        $displayName = _Get-TUACMECertDisplayName -Cert $Cert
        Write-Host "  Certificate '$displayName' imported to $scope\$storeName." -ForegroundColor Green
        Write-EventLogEntry -EventId 1006 -EntryType Information `
            -Message "TU-ACME: Imported $displayName to $scope\$storeName"
    } catch {
        Write-Host "  Import error: $_" -ForegroundColor Red
        if ("$_" -match 'denied|not authorized') {
            Write-Host "  Tip: writing to $scope\$storeName needs more rights." -ForegroundColor Yellow
            if ($scope -eq 'LocalMachine') {
                Write-Host '       Re-run TU-ACME elevated.' -ForegroundColor Yellow
            }
        }
    }

    Write-Host ''
    Wait-AnyKey
}
