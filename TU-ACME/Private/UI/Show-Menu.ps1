function Show-Menu {
    param(
        [Parameter(Mandatory)] [string]   $Title,
        [Parameter(Mandatory)] [string[]] $Options,
        [int]    $InitialIndex  = 0,
        [string] $StatusMessage = '',
        [switch] $AllowSearch
    )

    $w           = Get-ConsoleWidth
    $index       = $InitialIndex
    $filter      = ''
    $searching   = $false
    $allOptions  = $Options

    $visibleOptions = $allOptions
    $visibleIndices = 0..($allOptions.Count - 1)

    function Render-Menu {
        $saveLeft = Get-ConsoleCursorLeft
        $saveTop  = Get-ConsoleCursorTop
        Set-ConsoleCursorPos -X 0 -Y 0
        Set-ConsoleCursorVisible -Visible $false

        $border = '=' * [Math]::Min($w - 1, 79)
        Write-Host "  $Title" -ForegroundColor Cyan
        Write-Host "  $border" -ForegroundColor DarkCyan

        for ($i = 0; $i -lt $visibleOptions.Count; $i++) {
            Set-ConsoleCursorPos -X 0 -Y ($i + 2)
            $line = '  ' + $visibleOptions[$i]
            $line = $line.PadRight([Math]::Min($w - 1, 79))
            if ($i -eq $index) {
                Write-Host $line -ForegroundColor Black -BackgroundColor Cyan -NoNewline
            } else {
                Write-Host $line -ForegroundColor White -NoNewline
            }
        }

        # Ryd eventuelle resterende linjer
        $clearFrom = $visibleOptions.Count + 2
        for ($i = $clearFrom; $i -lt $clearFrom + 3; $i++) {
            Set-ConsoleCursorPos -X 0 -Y $i
            Write-Host (' ' * [Math]::Min($w - 1, 79)) -NoNewline
        }

        # Vis soegefelt hvis aktivt
        if ($AllowSearch) {
            Set-ConsoleCursorPos -X 0 -Y ($visibleOptions.Count + 3)
            if ($searching) {
                Write-Host "  Soeg: $filter_" -ForegroundColor Yellow -NoNewline
            } else {
                Write-Host '  [/] Soeg' -ForegroundColor DarkGray -NoNewline
            }
        }

        if ($StatusMessage -ne '') {
            Set-ConsoleCursorPos -X 0 -Y ($visibleOptions.Count + 4)
            Write-Host "  $StatusMessage" -ForegroundColor Yellow -NoNewline
        }

        Set-ConsoleCursorVisible -Visible $true
    }

    Invoke-ConsoleClear
    Render-Menu

    while ($true) {
        $key = Invoke-ConsoleReadKey

        # F3 — staging-toggle signal
        if ($key.Key -eq [ConsoleKey]::F3) {
            Set-ConsoleCursorVisible -Visible $true
            return -2
        }

        if ($searching) {
            if ($key.Key -eq [ConsoleKey]::Escape) {
                $searching = $false
                $filter    = ''
                $visibleOptions = $allOptions
                $visibleIndices = 0..($allOptions.Count - 1)
                $index = 0
                Invoke-ConsoleClear
                Render-Menu
                continue
            }
            if ($key.Key -eq [ConsoleKey]::Enter) {
                $searching = $false
                Invoke-ConsoleClear
                Render-Menu
                continue
            }
            if ($key.Key -eq [ConsoleKey]::Backspace) {
                if ($filter.Length -gt 0) {
                    $filter = $filter.Substring(0, $filter.Length - 1)
                }
            } elseif ($key.KeyChar -ne [char]0) {
                $filter += $key.KeyChar
            }

            # Filtrer options
            $filtered = @()
            $fIdx     = @()
            for ($i = 0; $i -lt $allOptions.Count; $i++) {
                if ($allOptions[$i] -match [regex]::Escape($filter)) {
                    $filtered += $allOptions[$i]
                    $fIdx     += $i
                }
            }
            $visibleOptions = $filtered
            $visibleIndices = $fIdx
            $index = 0
            Invoke-ConsoleClear
            Render-Menu
            continue
        }

        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($index -gt 0) { $index-- } else { $index = $visibleOptions.Count - 1 }
                Render-Menu
            }
            ([ConsoleKey]::DownArrow) {
                if ($index -lt $visibleOptions.Count - 1) { $index++ } else { $index = 0 }
                Render-Menu
            }
            ([ConsoleKey]::Enter) {
                Set-ConsoleCursorVisible -Visible $true
                return $visibleIndices[$index]
            }
            ([ConsoleKey]::Escape) {
                Set-ConsoleCursorVisible -Visible $true
                return -1
            }
            default {
                if ($AllowSearch -and $key.KeyChar -eq '/') {
                    $searching = $true
                    $filter    = ''
                    Render-Menu
                } elseif ($key.KeyChar -ge '1' -and $key.KeyChar -le '9') {
                    # Genvejstast: ciffer matcher optionens foerste ciffer
                    $digit = [int]::Parse($key.KeyChar.ToString()) - 1
                    if ($digit -ge 0 -and $digit -lt $visibleOptions.Count) {
                        Set-ConsoleCursorVisible -Visible $true
                        return $visibleIndices[$digit]
                    }
                } elseif ($key.KeyChar -eq 'q' -or $key.KeyChar -eq 'Q') {
                    # Q som genvej til afslut-option (sidst i listen)
                    Set-ConsoleCursorVisible -Visible $true
                    return $visibleIndices[$visibleOptions.Count - 1]
                }
            }
        }
    }
}
