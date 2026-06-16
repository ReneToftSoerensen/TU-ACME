function Get-TUACMERenewalStatusData {
    <#
    .SYNOPSIS
    Builds the renewal status report data set (UC-12.02).

    .DESCRIPTION
    Projects every certificate in the prod store with renewal metadata: expiry,
    days remaining, last renewal (the current cert's NotBefore), and the
    estimated next renewal (expiry minus the renewal threshold). Rows are sorted
    by days remaining (fewest first); certificates with an unknown expiry sort
    last. Returns summary counts for the report footer.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [int]$RenewThresholdDays = 30
    )

    $certificates = @(Get-TUACMECertificate)
    $now = Get-Date

    $rows = @()
    foreach ($certificate in $certificates) {
        $notAfter = $certificate.NotAfter

        $daysRemaining = $null
        $nextRenewal = $null
        if ($null -ne $notAfter) {
            $daysRemaining = [int][math]::Floor(((([datetime]$notAfter) - $now)).TotalDays)
            $nextRenewal = ([datetime]$notAfter).AddDays(-$RenewThresholdDays)
        }

        $lastRenewal = $null
        if ($null -ne $certificate.PSObject.Properties['NotBefore'] -and $null -ne $certificate.NotBefore) {
            $lastRenewal = $certificate.NotBefore
        }

        $rows += [pscustomobject]@{
            Domain        = [string]$certificate.MainDomain
            NotAfter      = $notAfter
            DaysRemaining = $daysRemaining
            LastRenewal   = $lastRenewal
            NextRenewal   = $nextRenewal
            Overdue       = ($null -ne $daysRemaining -and $daysRemaining -lt 0)
        }
    }

    # Sort fewest-days-first; a null expiry means unknown, not urgent, so it
    # sorts to the bottom.
    $rows = @($rows | Sort-Object -Property @{
            Expression = {
                if ($null -eq $_.DaysRemaining) { [int]::MaxValue } else { $_.DaysRemaining }
            }
        })

    $renewedLast24h = @($rows | Where-Object {
            $null -ne $_.LastRenewal -and ([datetime]$_.LastRenewal) -ge $now.AddDays(-1)
        }).Count

    return [pscustomobject]@{
        Rows           = $rows
        Total          = $rows.Count
        Valid          = @($rows | Where-Object { $null -ne $_.DaysRemaining -and $_.DaysRemaining -ge 0 }).Count
        Overdue        = @($rows | Where-Object { $_.Overdue }).Count
        RenewedLast24h = $renewedLast24h
    }
}
