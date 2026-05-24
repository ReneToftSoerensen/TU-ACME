function Invoke-LogViewer {
    <#
    .SYNOPSIS
        Reads TU-ACME provider events from the Application log and renders
        them in a paged, color-coded table. Optionally exports the current
        page to a CSV file.
    .DESCRIPTION
        Windows-only flow. Pulls 50 events at a time from
        Get-WinEvent -ProviderName 'TU-ACME'. Subsequent "next 50" requests
        accumulate a $skip offset and re-query the Application log.
        Errors are red, Warnings yellow, Information green.
        Export prompts before overwriting an existing destination file.
    #>
    [CmdletBinding()]
    param()

    if (-not $script:OnWindows) {
        Write-Host '  Event Log viewing not supported on this platform' -ForegroundColor Yellow
        return
    }

    $skip = 0

    while ($true) {
        $events = @(Get-WinEvent `
            -LogName Application `
            -FilterHashtable @{ ProviderName = 'TU-ACME' } `
            -MaxEvents 50 `
            -ErrorAction SilentlyContinue)

        # Drop already-seen records when paging forward.
        if ($skip -gt 0 -and $events.Count -gt 0) {
            if ($skip -ge $events.Count) {
                $events = @()
            } else {
                $events = @($events[$skip..($events.Count - 1)])
            }
        }

        if ($events.Count -eq 0) {
            Write-Host '  No TU-ACME events in the Application log' -ForegroundColor Yellow
            return
        }

        Invoke-ConsoleClear
        Write-Host ''
        Write-Host '  TU-ACME - Log Viewer' -ForegroundColor Cyan
        Write-Host '  ====================' -ForegroundColor DarkCyan
        Write-Host ''

        # Project a Message-truncated view so Show-Table renders cleanly.
        $rows = @($events | ForEach-Object {
            $msg = if ($_.Message) { "$($_.Message)" } else { '' }
            if ($msg.Length -gt 60) { $msg = $msg.Substring(0, 60) }
            [PSCustomObject]@{
                TimeCreated      = $_.TimeCreated
                Id               = $_.Id
                LevelDisplayName = $_.LevelDisplayName
                Message          = $msg
            }
        })

        $colorRule = {
            param($row)
            switch ($row.LevelDisplayName) {
                'Error'       { 'Red' }
                'Warning'     { 'Yellow' }
                'Information' { 'Green' }
                default       { 'White' }
            }
        }

        Show-Table `
            -Data $rows `
            -Columns @('TimeCreated', 'Id', 'LevelDisplayName', 'Message') `
            -ColorRule $colorRule

        Write-Host ''

        $options = @(
            '1. View next 50 events',
            '2. Export to file',
            'B. Back'
        )

        $selection = Show-Menu -Title 'TU-ACME - Log Viewer' -Options $options

        switch ($selection) {
            0 {
                $skip += 50
                continue
            }
            1 {
                $path = Read-Host '  Export path (e.g. C:\Temp\tuacme-events.csv)'
                if ([string]::IsNullOrWhiteSpace($path)) {
                    Write-Host '  Export cancelled (no path provided)' -ForegroundColor Yellow
                    continue
                }

                if (Test-Path -LiteralPath $path) {
                    $answer = Read-Host "  File exists. Overwrite? (y/N)"
                    if ($answer -ne 'y' -and $answer -ne 'Y') {
                        Write-Host '  Export cancelled' -ForegroundColor Yellow
                        continue
                    }
                }

                $events |
                    Select-Object TimeCreated, Id, LevelDisplayName, Message |
                    Export-Csv -Path $path -NoTypeInformation -Encoding UTF8

                Write-Host "  Exported to $path" -ForegroundColor Green
            }
            2       { return }
            -1      { return }
            default { return }
        }
    }
}
