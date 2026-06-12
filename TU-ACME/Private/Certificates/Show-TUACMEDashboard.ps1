function Show-TUACMEDashboard {
    [CmdletBinding()]
    param(
        [int]$PageSize = 15
    )

    $data = Get-TUACMEDashboardData

    $offset = 0
    while ($true) {
        Clear-Host
        Write-Host 'Certificate Dashboard' -ForegroundColor DarkCyan
        Write-Host ('{0,-28} {1,-12} {2,-12} {3,-42} {4}' -f 'Domain', 'Expires', 'Status', 'Thumbprint', 'IIS Bindings') -ForegroundColor DarkCyan

        if ($data.Total -eq 0) {
            Write-Host 'No certificates in the store yet. Order one from the main menu.' -ForegroundColor Cyan
        }

        $visible = @($data.Rows | Select-Object -Skip $offset -First $PageSize)
        foreach ($row in $visible) {
            $expiry = ''
            if ($null -ne $row.NotAfter) {
                $expiry = ([datetime]$row.NotAfter).ToString('yyyy-MM-dd')
            }

            # Flagged rows render in DarkCyan: the palette is locked to
            # Cyan/DarkCyan, so emphasis cannot use Red/Yellow (AC-C.4).
            $color = [System.ConsoleColor]::Cyan
            if (-not [string]::IsNullOrEmpty($row.Status)) {
                $color = [System.ConsoleColor]::DarkCyan
            }

            Write-Host ('{0,-28} {1,-12} {2,-12} {3,-42} {4}' -f $row.Domain, $expiry, $row.Status, $row.Thumbprint, $row.IISBindings) -ForegroundColor $color
        }

        Write-Host ('Total: {0}  Valid: {1}  Renew soon: {2}  Expired: {3}' -f $data.Total, $data.Valid, $data.RenewSoon, $data.Expired) -ForegroundColor Cyan
        Write-Host 'Up/Down scroll, Esc closes.' -ForegroundColor DarkCyan

        $key = Read-TUACMEKey
        switch ([string]$key.Key) {
            'UpArrow' {
                if ($offset -gt 0) { $offset-- }
            }
            'DownArrow' {
                if (($offset + $PageSize) -lt $data.Rows.Count) { $offset++ }
            }
            'Escape' { return }
            'Enter' { return }
            'Q' { return }
        }
    }
}
