function Show-StatusBar {
    param(
        [string] $ActiveAccount = '',
        [string] $AdminWarning  = '',
        [string] $LeftHint      = '[Up/Down] Navigate  [Enter] Select  [F3] Staging  [ESC] Back',
        [string] $RightHint     = ''
    )

    $w   = Get-ConsoleWidth
    $row = [Math]::Max((Get-ConsoleHeight) - 1, 0)

    $savedLeft = Get-ConsoleCursorLeft
    $savedTop  = Get-ConsoleCursorTop

    Set-ConsoleCursorVisible -Visible $false

    Set-ConsoleCursorPos -X 0 -Y $row

    if ($AdminWarning -ne '') {
        $warning = " WARNING: $AdminWarning "
        $padded  = $warning.PadRight($w)
        Write-Host $padded.Substring(0, $w) -ForegroundColor White -BackgroundColor Red -NoNewline
    } else {
        $left = $LeftHint
        if ($ActiveAccount -ne '') {
            $left = "  $ActiveAccount  |  $LeftHint"
        }
        $right   = if ($RightHint -ne '') { "  $RightHint  " } else { '' }
        $mid     = $w - $left.Length - $right.Length
        $mid     = [Math]::Max($mid, 0)
        $bar     = $left + (' ' * $mid) + $right
        $bar     = $bar.Substring(0, [Math]::Min($bar.Length, $w)).PadRight($w)
        Write-Host $bar.Substring(0, $w) -ForegroundColor Black -BackgroundColor Gray -NoNewline
    }

    Set-ConsoleCursorPos -X $savedLeft -Y $savedTop
    Set-ConsoleCursorVisible -Visible $true
}
