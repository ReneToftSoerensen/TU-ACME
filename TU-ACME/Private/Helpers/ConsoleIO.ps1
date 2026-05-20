function Invoke-ConsoleReadKey {
    try {
        return [Console]::ReadKey($true)
    } catch {
        return New-Object System.ConsoleKeyInfo([char]0, [System.ConsoleKey]::Escape, $false, $false, $false)
    }
}

function Invoke-ConsoleWaitKey {
    try { [Console]::ReadKey($true) | Out-Null } catch {}
}

function Invoke-ConsoleClear {
    try { [Console]::Clear() } catch {}
}

function Set-ConsoleCursorPos {
    param([int] $X, [int] $Y)
    try { [Console]::SetCursorPosition($X, $Y) } catch {}
}

function Get-ConsoleWidth {
    try { return [Math]::Max([Console]::WindowWidth, 80) } catch { return 80 }
}

function Get-ConsoleHeight {
    try { return [Math]::Max([Console]::WindowHeight, 24) } catch { return 24 }
}

function Get-ConsoleCursorLeft {
    try { return [Console]::CursorLeft } catch { return 0 }
}

function Get-ConsoleCursorTop {
    try { return [Console]::CursorTop } catch { return 0 }
}

function Set-ConsoleCursorVisible {
    param([bool] $Visible)
    try { [Console]::CursorVisible = $Visible } catch {}
}

function Wait-AnyKey {
    Write-Host '  Press any key...' -ForegroundColor DarkGray
    Invoke-ConsoleWaitKey
}

function Confirm-YesNo {
    param([Parameter(Mandatory)][string] $Prompt)
    $response = Read-Host $Prompt
    return ($response -match '^[Yy]')
}
