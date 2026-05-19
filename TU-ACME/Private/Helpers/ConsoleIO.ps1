function Invoke-ConsoleReadKey {
    return [Console]::ReadKey($true)
}

function Invoke-ConsoleWaitKey {
    [Console]::ReadKey($true) | Out-Null
}

function Invoke-ConsoleClear {
    [Console]::Clear()
}

function Set-ConsoleCursorPos {
    param([int] $X, [int] $Y)
    try { [Console]::SetCursorPosition($X, $Y) } catch {}
}

function Get-ConsoleWidth {
    return [Math]::Max([Console]::WindowWidth, 80)
}

function Get-ConsoleHeight {
    return [Math]::Max([Console]::WindowHeight, 24)
}
