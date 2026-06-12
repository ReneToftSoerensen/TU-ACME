function Get-TUACMEDashboardData {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [int]$RenewSoonDays = 30
    )

    $certificates = @(Get-TUACMECertificate)
    $bindings = @(Get-TUACMEIISBinding)

    $now = Get-Date
    $rows = @()
    foreach ($certificate in $certificates) {
        $thumbprint = [string]$certificate.Thumbprint

        $boundTo = @($bindings |
            Where-Object { $_.Thumbprint -eq $thumbprint } |
            ForEach-Object { ('{0} ({1})' -f $_.SiteName, $_.BindingInformation) })

        # A null NotAfter compares as less-than any date; it means unknown,
        # not expired, so leave the status blank.
        $status = ''
        if ($null -ne $certificate.NotAfter) {
            if ($certificate.NotAfter -lt $now) {
                $status = 'Expired'
            }
            elseif ($certificate.NotAfter -lt $now.AddDays($RenewSoonDays)) {
                $status = 'Renew Soon'
            }
        }

        $rows += [pscustomobject]@{
            Domain      = [string]$certificate.MainDomain
            NotAfter    = $certificate.NotAfter
            Thumbprint  = $thumbprint
            IISBindings = ($boundTo -join ', ')
            Status      = $status
        }
    }

    $rows = @($rows | Sort-Object -Property NotAfter)

    return [pscustomobject]@{
        Rows      = $rows
        Total     = $rows.Count
        Valid     = @($rows | Where-Object { $_.Status -ne 'Expired' }).Count
        RenewSoon = @($rows | Where-Object { $_.Status -eq 'Renew Soon' }).Count
        Expired   = @($rows | Where-Object { $_.Status -eq 'Expired' }).Count
    }
}
