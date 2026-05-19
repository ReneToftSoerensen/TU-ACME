function ConvertTo-MaskedInput {
    param(
        [Parameter(Mandatory)] [string] $Prompt,
        [char]   $MaskChar       = '*',
        [switch] $AsSecureString
    )

    Write-Host "${Prompt}: " -NoNewline

    $chars     = New-Object System.Collections.Generic.List[char]
    $secure    = New-Object System.Security.SecureString
    $col       = Get-ConsoleCursorLeft
    $row       = Get-ConsoleCursorTop

    while ($true) {
        $key = Invoke-ConsoleReadKey

        if ($key.Key -eq [ConsoleKey]::Enter) {
            Write-Host ''
            break
        }

        if ($key.Key -eq [ConsoleKey]::Escape) {
            Write-Host ''
            return $null
        }

        if ($key.Key -eq [ConsoleKey]::Backspace) {
            if ($chars.Count -gt 0) {
                $chars.RemoveAt($chars.Count - 1)
                if ($AsSecureString) {
                    $secure.RemoveAt($secure.Length - 1)
                }
                Set-ConsoleCursorPos -X $col -Y $row
                Write-Host ($MaskChar.ToString() * $chars.Count + ' ') -NoNewline
                Set-ConsoleCursorPos -X ($col + $chars.Count) -Y $row
            }
            continue
        }

        # Ignorer ikke-printbare tegn
        if ($key.KeyChar -eq [char]0) { continue }

        $chars.Add($key.KeyChar)
        if ($AsSecureString) {
            $secure.AppendChar($key.KeyChar)
        }
        Write-Host $MaskChar -NoNewline
    }

    if ($AsSecureString) {
        return $secure
    }
    return -join $chars
}
