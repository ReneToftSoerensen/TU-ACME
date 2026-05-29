function Read-LineOrEscape {
    <#
    .SYNOPSIS
        Read-Host-style line editor that returns $null when Escape is
        pressed, so callers can short-circuit the surrounding flow.
    .DESCRIPTION
        Echoes printable characters as the operator types, supports
        backspace, terminates on Enter (returning the accumulated
        string, possibly empty), and returns $null when Escape is
        pressed.

        Falls back to Read-Host when no interactive console is attached
        (Pester runs, CI, background scripts) so existing call sites
        that rely on stdin redirection continue to work. Esc-cancel is
        only available when a real TTY is present.
    #>
    param(
        [Parameter(Mandatory)] [string] $Prompt
    )

    if (-not (Test-InteractiveConsole)) {
        return Read-Host $Prompt
    }

    Write-Host "${Prompt}: " -NoNewline
    $chars = New-Object System.Collections.Generic.List[char]
    $col   = Get-ConsoleCursorLeft
    $row   = Get-ConsoleCursorTop

    while ($true) {
        $key = Invoke-ConsoleReadKey

        if ($key.Key -eq [ConsoleKey]::Enter) {
            Write-Host ''
            return (-join $chars)
        }

        if ($key.Key -eq [ConsoleKey]::Escape) {
            Write-Host ''
            return $null
        }

        if ($key.Key -eq [ConsoleKey]::Backspace) {
            if ($chars.Count -gt 0) {
                $chars.RemoveAt($chars.Count - 1)
                Set-ConsoleCursorPos -X $col -Y $row
                Write-Host ((-join $chars) + ' ') -NoNewline
                Set-ConsoleCursorPos -X ($col + $chars.Count) -Y $row
            }
            continue
        }

        # Ignore non-printable keys (arrows, function keys, etc).
        if ($key.KeyChar -eq [char]0) { continue }

        $chars.Add($key.KeyChar)
        Write-Host $key.KeyChar -NoNewline
    }
}
