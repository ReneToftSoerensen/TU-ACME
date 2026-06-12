function Invoke-TUACMEOrderCertificate {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Domain,

        [switch]$DryRun
    )

    $config = Get-TUACMEConfig
    $dns = Get-TUACMEDNSConfig

    # The order body takes its inputs as parameters (no closure) so it stays
    # bound to the module session state on both the prod and dry-run paths.
    $orderOperation = {
        param($OrderDomain, $ContactEmail, $DnsConfig)

        $orderParams = @{
            Domain      = $OrderDomain
            Contact     = $ContactEmail
            AcceptTOS   = $true
            ErrorAction = 'Stop'
        }
        if ($null -ne $DnsConfig) {
            $orderParams['Plugin'] = $DnsConfig.PluginName
            $orderParams['PluginArgs'] = $DnsConfig.PluginArgs
        }

        $certificate = New-PACertificate @orderParams
        if ($null -eq $certificate) {
            throw ('New-PACertificate returned no certificate for {0}.' -f $OrderDomain)
        }

        return [pscustomobject]@{
            Domain     = $OrderDomain
            Thumbprint = [string]$certificate.Thumbprint
            NotAfter   = $certificate.NotAfter
        }
    }

    if ($DryRun) {
        # Staging swap, prod restore, and event 1006 are owned by
        # Invoke-TUACMEDryRun (UC-3.01); dry-run certs are never imported.
        return (Invoke-TUACMEDryRun -Operation $orderOperation -ArgumentList @($Domain, $config.ContactEmail, $dns))
    }

    $null = Use-TUACMEProdAccount
    try {
        $result = & $orderOperation $Domain $config.ContactEmail $dns
    }
    catch {
        Write-TUACMEEventLog -EventId 3002 -EntryType Error -Message ('Certificate order for {0} failed: {1}' -f $Domain, $_.Exception.Message)
        throw
    }

    Write-TUACMEEventLog -EventId 1003 -EntryType Information -Message ('Certificate ordered for {0} (thumbprint {1}).' -f $result.Domain, $result.Thumbprint)
    return $result
}
