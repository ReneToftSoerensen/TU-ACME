function Invoke-LogViewer {
    # Find Posh-ACME log-filer
    $logDir   = Join-Path $env:LOCALAPPDATA 'Posh-ACME'
    $logFiles = @(Get-ChildItem -Path $logDir -Filter '*.log' -ErrorAction SilentlyContinue)

    if ($logFiles.Count -eq 0) {
        # Prøv ProgramData
        $logDir2   = Join-Path $env:ProgramData 'TU-ACME'
        $logFiles  = @(Get-ChildItem -Path $logDir2 -Filter '*.log' -ErrorAction SilentlyContinue)
    }

    if ($logFiles.Count -eq 0) {
        Write-Host '  Ingen logfiler fundet.' -ForegroundColor Yellow
        Write-Host '  Søgte i: ' -NoNewline; Write-Host $logDir -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '  Tryk en tast...' -ForegroundColor DarkGray
        [Console]::ReadKey($true) | Out-Null
        return
    }

    # Vaelg logfil hvis der er flere
    $logFile = $logFiles[0]
    if ($logFiles.Count -gt 1) {
        $options = $logFiles | ForEach-Object { $_.Name }
        $sel     = Show-Menu -Title 'Vaelg logfil' -Options $options
        if ($sel -lt 0) { return }
        $logFile = $logFiles[$sel]
    }

    _Show-LogPager -LogFile $logFile.FullName
}

function _Show-LogPager {
    param([string] $LogFile)

    $lines = @()
    try {
        $lines = @(Get-Content -Path $LogFile -Encoding UTF8 -ErrorAction Stop)
    } catch {
        Write-Host "  Fejl ved læsning af log: $_" -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }

    $h          = [Math]::Max([Console]::WindowHeight - 4, 5)
    $w          = [Math]::Max([Console]::WindowWidth, 80)
    $offset     = 0
    $maxOffset  = [Math]::Max($lines.Count - $h, 0)

    function Render-Page {
        [Console]::Clear()
        Write-Host "  === Log: $(Split-Path $LogFile -Leaf) ===" -ForegroundColor Cyan
        Write-Host "  Linje $($offset + 1)-$([Math]::Min($offset + $h, $lines.Count)) af $($lines.Count)" -ForegroundColor DarkGray

        $end = [Math]::Min($offset + $h, $lines.Count)
        for ($i = $offset; $i -lt $end; $i++) {
            $line = $lines[$i]
            if ($line.Length -gt $w - 3) { $line = $line.Substring(0, $w - 3) }

            $color = 'White'
            if ($line -match 'ERROR|FEJL|error')   { $color = 'Red' }
            elseif ($line -match 'WARN|Advars')     { $color = 'Yellow' }
            elseif ($line -match 'INFO|Succes|OK')  { $color = 'Green' }

            Write-Host "  $line" -ForegroundColor $color
        }

        Write-Host ''
        Write-Host '  [Pil op/ned] 1 linje  [PgUp/PgDn] Side  [Home/End] Top/Bund  [E] Eksporter  [ESC] Tilbage' -ForegroundColor DarkGray
    }

    Render-Page

    while ($true) {
        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            ([ConsoleKey]::Escape)   { return }
            ([ConsoleKey]::UpArrow)  {
                if ($offset -gt 0) { $offset--; Render-Page }
            }
            ([ConsoleKey]::DownArrow) {
                if ($offset -lt $maxOffset) { $offset++; Render-Page }
            }
            ([ConsoleKey]::PageUp)   {
                $offset = [Math]::Max($offset - $h, 0); Render-Page
            }
            ([ConsoleKey]::PageDown) {
                $offset = [Math]::Min($offset + $h, $maxOffset); Render-Page
            }
            ([ConsoleKey]::Home)     { $offset = 0; Render-Page }
            ([ConsoleKey]::End)      { $offset = $maxOffset; Render-Page }
            default {
                if ($key.KeyChar -eq 'e' -or $key.KeyChar -eq 'E') {
                    _Export-Log -LogFile $LogFile
                    Render-Page
                }
            }
        }
    }
}

function _Export-Log {
    param([string] $LogFile)

    $timestamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    $baseName   = [System.IO.Path]::GetFileNameWithoutExtension($LogFile)
    $desktop    = [System.Environment]::GetFolderPath('Desktop')
    $default    = Join-Path $desktop "${baseName}_${timestamp}.log"

    Write-Host ''
    Write-Host "  Destinationssti (standard: $default):" -ForegroundColor Gray
    $dest = Read-Host '  Sti'
    if ($dest -eq '') { $dest = $default }

    if ((Test-Path $dest)) {
        $overwrite = Read-Host "  '$dest' eksisterer. Overskriv? (J/N)"
        if ($overwrite -notmatch '^[Jj]') { return }
    }

    try {
        Copy-Item -Path $LogFile -Destination $dest -Force
        Write-Host "  Log eksporteret: $dest" -ForegroundColor Green
    } catch {
        Write-Host "  Fejl ved eksport: $_" -ForegroundColor Red
    }

    Start-Sleep -Seconds 1
}
