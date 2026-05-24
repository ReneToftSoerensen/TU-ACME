function Invoke-CertificateDashboard {
    <#
    .SYNOPSIS
        Interactive certificate dashboard.
    .DESCRIPTION
        Lists prod certificates via Get-PACertificate -List (after
        Use-TUACMEProdAccount), colors them by days-to-expiry against
        Dashboard.WarnDaysThreshold, sorts per Dashboard.DefaultSort,
        hides dry-runs unless 'd' is pressed, and opens the export menu
        when 'e' is pressed.

        Hotkeys:
          [D]     Toggle dry-runs pane
          [R]     Renew selected certificate
          [E]     Export menu
          [Enter] Details page for the first cert
          [Q|B]   Return
    #>
    [CmdletBinding()]
    param()

    Use-TUACMEProdAccount

    $certs = Show-Spinner -Message 'Loading certificates...' -ScriptBlock {
        Get-PACertificate -List
    }
    if ($null -eq $certs) { $certs = @() }
    # Ensure we always work with an array even when one cert is returned.
    $certs = @($certs)

    $cfg = Get-TUACMEConfig

    $warnDays     = 30
    $sort         = 'ExpiryAscending'
    $showDryRuns  = $false
    if ($cfg -and $cfg.PSObject.Properties.Match('Dashboard').Count -gt 0 -and $cfg.Dashboard) {
        if ($cfg.Dashboard.PSObject.Properties.Match('WarnDaysThreshold').Count -gt 0 -and
            $null -ne $cfg.Dashboard.WarnDaysThreshold) {
            $warnDays = [int]$cfg.Dashboard.WarnDaysThreshold
        }
        if ($cfg.Dashboard.PSObject.Properties.Match('DefaultSort').Count -gt 0 -and
            -not [string]::IsNullOrWhiteSpace($cfg.Dashboard.DefaultSort)) {
            $sort = [string]$cfg.Dashboard.DefaultSort
        }
        if ($cfg.Dashboard.PSObject.Properties.Match('ShowDryRunsByDefault').Count -gt 0 -and
            $null -ne $cfg.Dashboard.ShowDryRunsByDefault) {
            $showDryRuns = [bool]$cfg.Dashboard.ShowDryRunsByDefault
        }
    }

    # Partition prod vs dry-run certs.
    $dryRunCerts = @($certs | Where-Object { $_.FriendlyName -eq 'TU-ACME-DryRun' })
    $prodCerts   = @($certs | Where-Object { $_.FriendlyName -ne 'TU-ACME-DryRun' })

    # Sort per config.
    switch ($sort) {
        'ExpiryDescending' { $prodCerts = @($prodCerts | Sort-Object NotAfter -Descending) }
        'SubjectAscending' { $prodCerts = @($prodCerts | Sort-Object Subject) }
        default            { $prodCerts = @($prodCerts | Sort-Object NotAfter) }
    }
    $dryRunCerts = @($dryRunCerts | Sort-Object NotAfter -Descending)

    # Augment with DaysLeft so the table column is computable.
    $now = Get-Date
    $augment = {
        param($c)
        $daysLeft = $null
        if ($null -ne $c.NotAfter) {
            $daysLeft = [int]([Math]::Floor(([datetime]$c.NotAfter - $now).TotalDays))
        }
        [PSCustomObject]@{
            Subject      = $c.Subject
            NotAfter     = $c.NotAfter
            DaysLeft     = $daysLeft
            Thumbprint   = $c.Thumbprint
            FriendlyName = $c.FriendlyName
        }
    }
    $prodRows   = @($prodCerts   | ForEach-Object { & $augment $_ })
    $dryRunRows = @($dryRunCerts | ForEach-Object { & $augment $_ })

    $colorRule = {
        param($row)
        $d = $row.DaysLeft
        if ($null -eq $d)        { return 'White' }
        if ($d -le 0)            { return 'Red' }
        if ($d -le $warnDays)    { return 'Yellow' }
        return 'Green'
    }.GetNewClosure()

    while ($true) {
        Invoke-ConsoleClear
        Write-Host ''
        Write-Host '  === Certificate Dashboard ===' -ForegroundColor Cyan
        Write-Host ''

        if ($prodRows.Count -eq 0) {
            Write-Host '  No certificates found' -ForegroundColor Yellow
        } else {
            Show-Table `
                -Data      $prodRows `
                -Columns   @('Subject', 'NotAfter', 'DaysLeft', 'Thumbprint') `
                -Headers   @('Subject', 'NotAfter', 'DaysLeft', 'Thumbprint') `
                -ColorRule $colorRule
        }

        if ($showDryRuns) {
            Write-Host ''
            Write-Host '  Recent dry-runs' -ForegroundColor DarkCyan
            if ($dryRunRows.Count -eq 0) {
                Write-Host '  (none)' -ForegroundColor DarkGray
            } else {
                Show-Table `
                    -Data      $dryRunRows `
                    -Columns   @('Subject', 'NotAfter', 'DaysLeft', 'Thumbprint') `
                    -Headers   @('Subject', 'NotAfter', 'DaysLeft', 'Thumbprint') `
                    -ColorRule $colorRule
            }
        }

        Write-Host ''
        Write-Host '  [D] Toggle dry-runs   [R] Renew selected   [E] Export   [Enter] Details   [Esc] Back' -ForegroundColor DarkCyan

        $input = Read-Host '  >'
        if ($null -eq $input) { return }
        $key = ($input).ToString().Trim().ToLowerInvariant()

        switch ($key) {
            'd' {
                $showDryRuns = -not $showDryRuns
            }
            'r' {
                if (Get-Command -Name 'Invoke-RenewSelectedCertificate' -ErrorAction SilentlyContinue) {
                    Invoke-RenewSelectedCertificate
                } else {
                    Write-Host '  Not yet implemented' -ForegroundColor Yellow
                    Wait-AnyKey
                }
            }
            'e' {
                if (Get-Command -Name 'Invoke-ExportMenu' -ErrorAction SilentlyContinue) {
                    Invoke-ExportMenu
                } else {
                    Write-Host '  Export menu not available' -ForegroundColor Yellow
                    Wait-AnyKey
                }
            }
            '' {
                if ($prodRows.Count -eq 0) {
                    Write-Host '  No certificates' -ForegroundColor Yellow
                    Wait-AnyKey
                } else {
                    $first = $prodRows[0]
                    Invoke-ConsoleClear
                    Write-Host ''
                    Write-Host '  === Certificate Details ===' -ForegroundColor Cyan
                    Write-Host ''
                    Write-Host "  Subject     : $($first.Subject)"
                    Write-Host "  NotAfter    : $($first.NotAfter)"
                    Write-Host "  DaysLeft    : $($first.DaysLeft)"
                    Write-Host "  Thumbprint  : $($first.Thumbprint)"
                    Write-Host "  FriendlyName: $($first.FriendlyName)"
                    Write-Host ''
                    Wait-AnyKey
                }
            }
            'q' { return }
            'b' { return }
            'esc' { return }
            'escape' { return }
            default {
                # Unknown key: re-render.
            }
        }
    }
}
