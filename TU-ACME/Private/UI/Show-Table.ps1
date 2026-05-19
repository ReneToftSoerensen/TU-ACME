function Show-Table {
    param(
        [Parameter(Mandatory)] [object[]]  $Data,
        [Parameter(Mandatory)] [string[]]  $Columns,
        [string[]]    $Headers     = @(),
        [int[]]       $Widths      = @(),
        [scriptblock] $ColorRule   = $null,
        [int]         $SelectedIndex = -1,
        [switch]      $Interactive
    )

    $w = [Math]::Max([Console]::WindowWidth, 80)

    # Brug Columns som Headers hvis ikke angivet
    if ($Headers.Count -eq 0) { $Headers = $Columns }

    # Beregn kolonnebredder hvis ikke angivet
    if ($Widths.Count -eq 0) {
        $colW = [Math]::Max(([int](($w - 4) / $Columns.Count)), 10)
        $Widths = $Columns | ForEach-Object { $colW }
    }

    function Render-Table {
        param([int] $CurrentIndex)

        # Header
        $header = ''
        for ($c = 0; $c -lt $Columns.Count; $c++) {
            $header += $Headers[$c].PadRight($Widths[$c]).Substring(0, [Math]::Min($Widths[$c], $Headers[$c].Length + 1)).PadRight($Widths[$c])
            if ($c -lt $Columns.Count - 1) { $header += ' | ' }
        }
        Write-Host "  $header" -ForegroundColor White
        Write-Host ('  ' + ('-' * [Math]::Min($header.Length, $w - 3))) -ForegroundColor DarkGray

        for ($r = 0; $r -lt $Data.Count; $r++) {
            $row    = $Data[$r]
            $line   = ''
            for ($c = 0; $c -lt $Columns.Count; $c++) {
                $val   = if ($row.($Columns[$c]) -ne $null) { "$($row.($Columns[$c]))" } else { '' }
                $cell  = $val.PadRight($Widths[$c])
                $cell  = $cell.Substring(0, [Math]::Min($cell.Length, $Widths[$c]))
                $line += $cell
                if ($c -lt $Columns.Count - 1) { $line += ' | ' }
            }

            $fgColor = 'White'
            if ($ColorRule -ne $null) {
                $ruleColor = & $ColorRule $row
                if ($ruleColor -ne $null) { $fgColor = $ruleColor }
            }

            $lineOut = '  ' + $line
            if ($Interactive -and $r -eq $CurrentIndex) {
                Write-Host $lineOut -ForegroundColor Black -BackgroundColor Cyan
            } else {
                Write-Host $lineOut -ForegroundColor $fgColor
            }
        }
    }

    if (-not $Interactive) {
        Render-Table -CurrentIndex -1
        return
    }

    # Interaktiv tilstand — piletaster, Enter returnerer index
    $index = if ($SelectedIndex -ge 0) { $SelectedIndex } else { 0 }
    if ($Data.Count -eq 0) {
        Write-Host '  (Ingen data)' -ForegroundColor DarkGray
        return -1
    }

    Invoke-ConsoleClear
    Render-Table -CurrentIndex $index

    try { [Console]::CursorVisible = $false } catch {}

    while ($true) {
        $key = Invoke-ConsoleReadKey

        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($index -gt 0) { $index-- }
                Invoke-ConsoleClear
                Render-Table -CurrentIndex $index
            }
            ([ConsoleKey]::DownArrow) {
                if ($index -lt $Data.Count - 1) { $index++ }
                Invoke-ConsoleClear
                Render-Table -CurrentIndex $index
            }
            ([ConsoleKey]::Enter) {
                try { [Console]::CursorVisible = $true } catch {}
                return $index
            }
            ([ConsoleKey]::Escape) {
                try { [Console]::CursorVisible = $true } catch {}
                return -1
            }
        }
    }
}
