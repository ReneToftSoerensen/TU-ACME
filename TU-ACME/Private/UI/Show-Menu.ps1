function Show-Menu {
    param(
        [Parameter(Mandatory)] [string]   $Title,
        [Parameter(Mandatory)] [string[]] $Options,
        [int]    $InitialIndex  = 0,
        [string] $StatusMessage = '',
        [switch] $AllowSearch
    )

    # The menu content is anchored to the left edge regardless of terminal width:
    # Width caps at 79 so wide terminals do not stretch lines toward the right,
    # and the cursor is always placed with X = 0.
    $w           = [Math]::Min((Get-ConsoleWidth) - 1, 79)
    $index       = $InitialIndex
    $filter      = ''
    $searching   = $false
    $allOptions  = $Options

    $visibleOptions = $allOptions
    $visibleIndices = 0..($allOptions.Count - 1)

    function Render-Menu {
        Set-ConsoleCursorPos -X 0 -Y 0
        Set-ConsoleCursorVisible -Visible $false

        $border = '=' * $w
        Write-Host "  $Title".PadRight($w) -ForegroundColor Cyan -NoNewline
        Set-ConsoleCursorPos -X 0 -Y 1
        Write-Host "  $border" -ForegroundColor DarkCyan -NoNewline

        for ($i = 0; $i -lt $visibleOptions.Count; $i++) {
            Set-ConsoleCursorPos -X 0 -Y ($i + 2)
            $line = ('  ' + $visibleOptions[$i]).PadRight($w)
            if ($i -eq $index) {
                Write-Host $line -ForegroundColor Black -BackgroundColor Cyan -NoNewline
            } else {
                Write-Host $line -ForegroundColor White -NoNewline
            }
        }

        # Clear any remaining lines
        $clearFrom = $visibleOptions.Count + 2
        for ($i = $clearFrom; $i -lt $clearFrom + 3; $i++) {
            Set-ConsoleCursorPos -X 0 -Y $i
            Write-Host (' ' * $w) -NoNewline
        }

        # Show search field if active — always anchored at X = 0
        if ($AllowSearch) {
            Set-ConsoleCursorPos -X 0 -Y ($visibleOptions.Count + 3)
            if ($searching) {
                Write-Host "  Search: ${filter}_" -ForegroundColor Yellow -NoNewline
            } else {
                Write-Host '  [/] Search' -ForegroundColor DarkGray -NoNewline
            }
        }

        if ($StatusMessage -ne '') {
            Set-ConsoleCursorPos -X 0 -Y ($visibleOptions.Count + 4)
            Write-Host "  $StatusMessage" -ForegroundColor Yellow -NoNewline
        }

        # Place the cursor at the left edge immediately after the search text
        # while the user types, so input appears from the left side.
        if ($AllowSearch -and $searching) {
            Set-ConsoleCursorPos -X (8 + $filter.Length) -Y ($visibleOptions.Count + 3)
            Set-ConsoleCursorVisible -Visible $true
        } else {
            Set-ConsoleCursorPos -X 0 -Y ($visibleOptions.Count + 5)
            Set-ConsoleCursorVisible -Visible $false
        }
    }

    Invoke-ConsoleClear
    Render-Menu

    try {
        while ($true) {
            $key = Invoke-ConsoleReadKey

            # F3 — staging-toggle signal
            if ($key.Key -eq [ConsoleKey]::F3) {
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

                # Filter options
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
                    return $visibleIndices[$index]
                }
                ([ConsoleKey]::Escape) {
                    return -1
                }
                default {
                    if ($AllowSearch -and $key.KeyChar -eq '/') {
                        $searching = $true
                        $filter    = ''
                        Render-Menu
                    } elseif ($key.KeyChar -ge '1' -and $key.KeyChar -le '9') {
                        # Hotkey: digit matches the option's leading digit
                        $digit = [int]::Parse($key.KeyChar.ToString()) - 1
                        if ($digit -ge 0 -and $digit -lt $visibleOptions.Count) {
                            return $visibleIndices[$digit]
                        }
                    } elseif ($key.KeyChar -eq 'q' -or $key.KeyChar -eq 'Q') {
                        # Q as shortcut for the exit option (last in the list)
                        return $visibleIndices[$visibleOptions.Count - 1]
                    }
                }
            }
        }
    }
    finally {
        # Forlad altid Show-Menu med markoeren ved kolonne 0 paa en frisk
        # linje under menuens indhold, saa kalderen kan skrive input/output
        # forankret til venstre side ogsaa paa brede terminaler.
        $lastRow = [Math]::Min($visibleOptions.Count + 5, [Math]::Max((Get-ConsoleHeight) - 1, 0))
        Set-ConsoleCursorPos -X 0 -Y $lastRow
        Set-ConsoleCursorVisible -Visible $true
    }
}
