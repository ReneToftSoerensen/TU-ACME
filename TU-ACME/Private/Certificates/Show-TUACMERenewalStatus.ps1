function Show-TUACMERenewalStatus {
    <#
    .SYNOPSIS
    Read-only renewal status report (UC-12.02).

    .DESCRIPTION
    Renders all certificates sorted by days remaining, highlighting overdue rows
    in DarkCyan (the palette is locked to Cyan/DarkCyan, AC-C.4). Keyboard
    navigable: Up/Down scroll, R refreshes on demand, Esc/Enter/Q closes.
    #>
    [CmdletBinding()]
    param(
        [ValidateRange(1, [int]::MaxValue)]
        [int]$PageSize = 15
    )

    $data = Get-TUACMERenewalStatusData
    $offset = 0

    while ($true) {
        Clear-Host
        Write-Host 'Renewal Status' -ForegroundColor DarkCyan
        Write-Host ('{0,-28} {1,-12} {2,-6} {3,-12} {4,-12}' -f 'Domain', 'Expires', 'Days', 'Last Renew', 'Next Renew') -ForegroundColor DarkCyan

        if ($data.Total -eq 0) {
            Write-Host 'No certificates in the store yet. Order one from the main menu.' -ForegroundColor Cyan
        }

        $visible = @($data.Rows | Select-Object -Skip $offset -First $PageSize)
        foreach ($row in $visible) {
            $expiry = ''
            if ($null -ne $row.NotAfter) {
                $expiry = ([datetime]$row.NotAfter).ToString('yyyy-MM-dd')
            }
            $lastRenew = ''
            if ($null -ne $row.LastRenewal) {
                $lastRenew = ([datetime]$row.LastRenewal).ToString('yyyy-MM-dd')
            }
            $nextRenew = ''
            if ($null -ne $row.NextRenewal) {
                $nextRenew = ([datetime]$row.NextRenewal).ToString('yyyy-MM-dd')
            }
            $days = ''
            if ($null -ne $row.DaysRemaining) {
                $days = [string]$row.DaysRemaining
            }

            # Overdue rows render in DarkCyan; the palette is locked (AC-C.4).
            $color = [System.ConsoleColor]::Cyan
            if ($row.Overdue) {
                $color = [System.ConsoleColor]::DarkCyan
            }

            Write-Host ('{0,-28} {1,-12} {2,-6} {3,-12} {4,-12}' -f $row.Domain, $expiry, $days, $lastRenew, $nextRenew) -ForegroundColor $color
        }

        Write-Host ('Total: {0}  Valid: {1}  Overdue: {2}  Renewed 24h: {3}' -f $data.Total, $data.Valid, $data.Overdue, $data.RenewedLast24h) -ForegroundColor Cyan
        Write-Host 'Up/Down scroll, R refresh, Esc/Enter/Q closes.' -ForegroundColor DarkCyan

        $key = Read-TUACMEKey
        switch ([string]$key.Key) {
            'UpArrow' {
                if ($offset -gt 0) { $offset-- }
            }
            'DownArrow' {
                if (($offset + $PageSize) -lt $data.Rows.Count) { $offset++ }
            }
            'R' {
                $data = Get-TUACMERenewalStatusData
                $offset = 0
            }
            'Escape' { return }
            'Enter' { return }
            'Q' { return }
        }
    }
}
