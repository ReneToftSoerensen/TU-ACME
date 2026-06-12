function Show-TUACMEDashboard {
    [CmdletBinding()]
    param(
        [ValidateRange(1, [int]::MaxValue)]
        [int]$PageSize = 15
    )

    $bindings = @(Get-TUACMEIISBinding)
    $data = Get-TUACMEDashboardData -Bindings $bindings

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

        # All IIS bindings, including ones whose certificate is not in the
        # Posh-ACME store (AC-G.1); blanks mean the thumbprint did not
        # resolve in WebHosting or My.
        if ($bindings.Count -gt 0) {
            Write-Host 'IIS bindings' -ForegroundColor DarkCyan
            Write-Host ('{0,-24} {1,-7} {2,-28} {3,-42} {4,-12} {5}' -f 'Site', 'Proto', 'Host', 'Thumbprint', 'Expires', 'Template') -ForegroundColor DarkCyan
            foreach ($binding in $bindings) {
                $bindingExpiry = ''
                if ($null -ne $binding.NotAfter) {
                    $bindingExpiry = ([datetime]$binding.NotAfter).ToString('yyyy-MM-dd')
                }
                Write-Host ('{0,-24} {1,-7} {2,-28} {3,-42} {4,-12} {5}' -f $binding.SiteName, $binding.Protocol, $binding.HostHeader, $binding.Thumbprint, $bindingExpiry, $binding.Template) -ForegroundColor Cyan
            }
        }

        Write-Host 'Up/Down scroll, Esc/Enter/Q closes.' -ForegroundColor DarkCyan

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
