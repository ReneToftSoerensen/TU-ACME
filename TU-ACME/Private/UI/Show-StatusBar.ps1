function Show-StatusBar {
    param(
        [string] $ActiveAccount = '',
        [string] $AdminWarning  = '',
        [string] $LeftHint      = '[Pil op/ned] Naviger  [Enter] Vaelg  [F3] Staging  [ESC] Tilbage',
        [string] $RightHint     = ''
    )

    $w   = [Math]::Max([Console]::WindowWidth, 80)
    $row = [Math]::Max([Console]::WindowHeight - 1, 0)

    $savedLeft = [Console]::CursorLeft
    $savedTop  = [Console]::CursorTop

    try { [Console]::CursorVisible = $false } catch {}

    [Console]::SetCursorPosition(0, $row)

    if ($AdminWarning -ne '') {
        $warning = " ADVARSEL: $AdminWarning "
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

    [Console]::SetCursorPosition($savedLeft, $savedTop)
    try { [Console]::CursorVisible = $true } catch {}
}
