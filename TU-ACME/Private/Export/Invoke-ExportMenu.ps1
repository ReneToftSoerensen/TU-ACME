function Invoke-ExportMenu {
    <#
    .SYNOPSIS
        Interactive export / import menu for prod certificates.
    .DESCRIPTION
        Switches Posh-ACME to the prod account, lists the certificates
        owned by that account, and lets the operator either export the
        selected certificate to a PFX (password-protected) file, export
        it to a concatenated PEM (chain + private key, no password), or
        import it directly into the LocalMachine\My Windows certificate
        store. Emits Event 1009 on PFX export and Event 1011 on store
        import.
    #>
    [CmdletBinding()]
    param()

    Use-TUACMEProdAccount

    $certs = @(Get-PACertificate -List)
    if ($certs.Count -eq 0) {
        Write-Host '  No certificates available' -ForegroundColor Yellow
        return
    }

    # Project rows for the listing table.
    $rows = @()
    for ($i = 0; $i -lt $certs.Count; $i++) {
        $c = $certs[$i]
        $rows += [PSCustomObject]@{
            Index      = $i + 1
            Subject    = $c.Subject
            NotAfter   = $c.NotAfter
            Thumbprint = $c.Thumbprint
        }
    }

    Invoke-ConsoleClear
    Write-Host ''
    Write-Host '  === Export / Import Certificate ===' -ForegroundColor Cyan
    Write-Host ''

    Show-Table `
        -Data    $rows `
        -Columns @('Index', 'Subject', 'NotAfter', 'Thumbprint') `
        -Headers @('#',     'Subject', 'NotAfter', 'Thumbprint')

    Write-Host ''

    # ---- 1. Pick a certificate ------------------------------------------
    $picked = $null
    while ($true) {
        $raw = Read-Host '  Certificate # to export'
        if ([string]::IsNullOrWhiteSpace($raw)) {
            Write-Host '  Cancelled' -ForegroundColor Yellow
            return
        }
        $n = 0
        if ([int]::TryParse($raw, [ref]$n) -and $n -ge 1 -and $n -le $certs.Count) {
            $picked = $certs[$n - 1]
            break
        }
        Write-Host "  Invalid index. Enter 1..$($certs.Count)." -ForegroundColor Yellow
    }

    $subject    = $picked.Subject
    $thumbprint = $picked.Thumbprint

    # ---- 2. Pick a format ------------------------------------------------
    $options = @(
        '1. PFX (password protected)',
        '2. PEM (no password)',
        '3. Import to Windows certificate store (LocalMachine\My)',
        'B. Back'
    )
    $sel = Show-Menu -Title 'Export / Import format' -Options $options
    if ($sel -lt 0 -or $sel -eq 3) { return }

    $cwd      = (Get-Location).Path
    $safeName = ($subject -replace '[^a-zA-Z0-9.\-_]', '_')

    switch ($sel) {
        0 {
            # ---- PFX ---------------------------------------------------
            $default = Join-Path $cwd ("$safeName.pfx")
            $path    = Read-Host "  Destination PFX path [$default]"
            if ([string]::IsNullOrWhiteSpace($path)) { $path = $default }

            if (Test-Path -LiteralPath $path) {
                $answer = Read-Host '  File exists. Overwrite? (y/N)'
                if ($answer -ne 'y' -and $answer -ne 'Y') {
                    Write-Host '  Export cancelled' -ForegroundColor Yellow
                    return
                }
            }

            $pwd = Read-Host '  PFX password' -AsSecureString

            try {
                Export-PfxCertificate `
                    -Cert     "Cert:\LocalMachine\My\$thumbprint" `
                    -FilePath $path `
                    -Password $pwd | Out-Null
            } catch {
                Write-Host "  PFX export failed: $($_.Exception.Message)" -ForegroundColor Yellow
                return
            }

            Write-EventLogEntry -EventId 1009 -EntryType Information `
                -Message "PFX exported: $subject -> $path (thumbprint $thumbprint)"
            Write-Host "  Exported PFX to $path" -ForegroundColor Green
        }
        1 {
            # ---- PEM ---------------------------------------------------
            $default = Join-Path $cwd ("$safeName.pem")
            $path    = Read-Host "  Destination PEM path [$default]"
            if ([string]::IsNullOrWhiteSpace($path)) { $path = $default }

            if (Test-Path -LiteralPath $path) {
                $answer = Read-Host '  File exists. Overwrite? (y/N)'
                if ($answer -ne 'y' -and $answer -ne 'Y') {
                    Write-Host '  Export cancelled' -ForegroundColor Yellow
                    return
                }
            }

            $cert = Get-PACertificate -MainDomain $subject
            if ($null -eq $cert) {
                Write-Host "  Could not resolve certificate for $subject" -ForegroundColor Yellow
                return
            }

            try {
                $chainLines = @(Get-Content -LiteralPath $cert.FullChainFile)
                $keyLines   = @(Get-Content -LiteralPath $cert.KeyFile)
                $chain      = ($chainLines -join "`r`n")
                $key        = ($keyLines   -join "`r`n")
                Set-Content -LiteralPath $path -Value ($chain + "`r`n" + $key)
            } catch {
                Write-Host "  PEM export failed: $($_.Exception.Message)" -ForegroundColor Yellow
                return
            }

            Write-Host "  Exported PEM to $path" -ForegroundColor Green
        }
        2 {
            # ---- Import to store --------------------------------------
            $cert = Get-PACertificate -MainDomain $subject
            if ($null -eq $cert) {
                Write-Host "  Could not resolve certificate for $subject" -ForegroundColor Yellow
                return
            }

            try {
                $securePass = ConvertTo-SecureString $cert.PfxPass -AsPlainText -Force
                $imported   = Import-PfxCertificate `
                    -FilePath          $cert.PfxFile `
                    -CertStoreLocation 'Cert:\LocalMachine\My' `
                    -Password          $securePass
            } catch {
                Write-Host "  Import failed: $($_.Exception.Message)" -ForegroundColor Yellow
                return
            }

            $newThumb = if ($imported -and $imported.Thumbprint) { $imported.Thumbprint } else { $thumbprint }

            Write-EventLogEntry -EventId 1011 -EntryType Information `
                -Message "Certificate imported to LocalMachine\My: $subject (thumbprint $newThumb)"
            Write-Host "  Imported to LocalMachine\My (thumbprint $newThumb)" -ForegroundColor Green
        }
    }
}
