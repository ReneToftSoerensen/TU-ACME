function Invoke-LogViewer {
    # Find Posh-ACME log files
    $logDir   = Join-Path $env:LOCALAPPDATA 'Posh-ACME'
    $logFiles = @(Get-ChildItem -Path $logDir -Filter '*.log' -ErrorAction SilentlyContinue)

    if ($logFiles.Count -eq 0) {
        # Try ProgramData
        $logDir2   = Join-Path $env:ProgramData 'TU-ACME'
        $logFiles  = @(Get-ChildItem -Path $logDir2 -Filter '*.log' -ErrorAction SilentlyContinue)
    }

    if ($logFiles.Count -eq 0) {
        Write-Host '  No log files found.' -ForegroundColor Yellow
        Write-Host '  Searched in: ' -NoNewline; Write-Host $logDir -ForegroundColor DarkGray
        Write-Host ''
        Wait-AnyKey
        return
    }

    # Select log file if there are several
    $logFile = $logFiles[0]
    if ($logFiles.Count -gt 1) {
        $options = $logFiles | ForEach-Object { $_.Name }
        $sel     = Show-Menu -Title 'Select log file' -Options $options
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
        Write-Host "  Error reading log: $_" -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }

    $h          = [Math]::Max((Get-ConsoleHeight) - 4, 5)
    $w          = Get-ConsoleWidth
    $offset     = 0
    $maxOffset  = [Math]::Max($lines.Count - $h, 0)

    function Render-Page {
        Invoke-ConsoleClear
        Write-Host "  === Log: $(Split-Path $LogFile -Leaf) ===" -ForegroundColor Cyan
        Write-Host "  Line $($offset + 1)-$([Math]::Min($offset + $h, $lines.Count)) of $($lines.Count)" -ForegroundColor DarkGray

        $end = [Math]::Min($offset + $h, $lines.Count)
        for ($i = $offset; $i -lt $end; $i++) {
            $line = $lines[$i]
            if ($line.Length -gt $w - 3) { $line = $line.Substring(0, $w - 3) }

            $color = 'White'
            if ($line -match 'ERROR|error')         { $color = 'Red' }
            elseif ($line -match 'WARN|Warning')    { $color = 'Yellow' }
            elseif ($line -match 'INFO|Success|OK') { $color = 'Green' }

            Write-Host "  $line" -ForegroundColor $color
        }

        Write-Host ''
        Write-Host '  [Up/Down] 1 line  [PgUp/PgDn] Page  [Home/End] Top/Bottom  [E] Export  [ESC] Back' -ForegroundColor DarkGray
    }

    Render-Page

    while ($true) {
        $key = Invoke-ConsoleReadKey

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
    if (-not $desktop) { $desktop = [System.IO.Path]::GetTempPath() }
    $default    = Join-Path $desktop "${baseName}_${timestamp}.log"

    Write-Host ''
    Write-Host "  Destination path (default: $default):" -ForegroundColor Gray
    $dest = Read-Host '  Path'
    if ($dest -eq '') { $dest = $default }

    if ((Test-Path $dest)) {
        if (-not (Confirm-YesNo "  '$dest' exists. Overwrite? (y/N)" -Default $false)) { return }
    }

    try {
        Copy-Item -Path $LogFile -Destination $dest -Force
        Write-Host "  Log exported: $dest" -ForegroundColor Green
    } catch {
        Write-Host "  Export error: $_" -ForegroundColor Red
    }

    Start-Sleep -Seconds 1
}
